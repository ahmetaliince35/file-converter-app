import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dosya_converter/core/widgets/coversion_progress_overlay.dart';
import '../../../../core/theme/theme_view_model.dart';
import '../../../../core/widgets/feedback_snack_bar.dart';
import '../../../auth/data/google_auth_service.dart';
import '../../../auth/data/microsoft_auth_service.dart';
import '../../../convert/domain/conversion_kind.dart';
import '../../../convert/presentation/screens/image_to_pdf_screen.dart';
import '../../../ocr/presentation/snippet_ocr_screen.dart';
import '../../../pdf_tools/presentation/pdf_studio_screen.dart';
import '../../../share/presentation/screens/qr_share_screen.dart';
import '../../../transcribe/data/audio_to_text_converter.dart';
import '../../../transcribe/presentation/audio_to_text_screen.dart';
import '../../../transcribe/presentation/widget/api_key_dialog.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeViewModel get _home => context.read<HomeViewModel>();

  void _notify(HomeOpResult result) {
    if (!mounted) return;
    showFeedbackSnackBar(
      context,
      message: result.message,
      icon: result.isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      backgroundColor: result.isSuccess ? Colors.teal.shade700 : Colors.red.shade800,
    );
  }

  Future<void> _shareSingleFile(File file) async {
    HapticFeedback.lightImpact();
    if (!await file.exists()) {
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: 'Paylaşılacak dosya bulunamadı.',
        icon: Icons.error_outline_rounded,
        backgroundColor: Colors.red.shade800,
      );
      return;
    }
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _handleDirectQrSend() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      await FilePicker.platform.clearTemporaryFiles();
      return;
    }

    final fileToSend = File(result.files.single.path!);
    const int maxBytes = 1024 * 1024 * 1024;

    if (fileToSend.lengthSync() > maxBytes) {
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: 'Seçilen dosya 1 GB sınırını aşıyor!',
        icon: Icons.warning_amber_rounded,
        backgroundColor: Colors.amber.shade900,
      );
      await FilePicker.platform.clearTemporaryFiles();
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrShareScreen(file: fileToSend)),
    );
  }

  Future<void> _processCategory({
    required List<String> extensions,
    required ConversionKind kind,
  }) async {
    HapticFeedback.selectionClick();

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result == null || result.files.isEmpty) return;

    final validFiles = <File>[];

    for (final pf in result.files) {
      if (pf.path != null) {
        final file = File(pf.path!);
        int lastSize = -1;
        int stableCount = 0;

        for (int i = 0; i < 15; i++) {
          if (await file.exists()) {
            final currentSize = await file.length();
            if (currentSize > 0 && currentSize == lastSize) {
              stableCount++;
              if (stableCount >= 2) break;
            } else {
              stableCount = 0;
            }
            lastSize = currentSize;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (await file.exists()) {
          validFiles.add(file);
        }
      }
    }

    if (validFiles.isEmpty) {
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: 'Dosya açılamadı veya kopyalanamadı.',
        icon: Icons.error_outline_rounded,
        backgroundColor: Colors.red.shade800,
      );
      return;
    }

    final op = await _home.processFiles(files: validFiles, kind: kind);
    _notify(op);
  }

  Future<void> _handleAudioToText() async {
    HapticFeedback.lightImpact();

    final apiKey = await AudioToTextConverter.getSavedApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      showApiKeyDialog(context, onSaved: () {
        if (mounted) {
          Navigator.push<File>(
            context,
            MaterialPageRoute(builder: (context) => const AudioToTextScreen()),
          ).then((resultTxt) {
            if (resultTxt != null && mounted) {
              _home.addResult(resultTxt);
              showFeedbackSnackBar(
                context,
                message: 'Ses kaydı metne dönüştürüldü!',
                icon: Icons.check_circle_rounded,
                backgroundColor: Colors.teal.shade700,
              );
            }
          });
        }
      });
      return;
    }

    final File? resultTxt = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => const AudioToTextScreen()),
    );

    if (resultTxt != null && mounted) {
      _home.addResult(resultTxt);
      showFeedbackSnackBar(
        context,
        message: 'Ses kaydı metne dönüştürüldü!',
        icon: Icons.check_circle_rounded,
        backgroundColor: Colors.teal.shade700,
      );
    }
  }

  Future<void> _handleDocScanner() async {
    HapticFeedback.lightImpact();

    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.pdf,
          mode: ScannerMode.full,
          pageLimit: 25,
          isGalleryImport: true,
        ),
      );

      final DocumentScanningResult result = await documentScanner.scanDocument();
      await documentScanner.close();

      final pdfUriString = result.pdf?.uri;

      if (pdfUriString != null && mounted) {
        final uri = Uri.parse(pdfUriString);
        final scannedFile = uri.isScheme('file') ? File.fromUri(uri) : File(pdfUriString);

        if (await scannedFile.exists()) {
          final tempDir = await getTemporaryDirectory();
          final targetPath = p.join(
            tempDir.path,
            'tarama_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
          final finalPdf = await scannedFile.copy(targetPath);

          _home.addResult(finalPdf);
          showFeedbackSnackBar(
            context,
            message: 'Taranmış A4 PDF başarıyla oluşturuldu!',
            icon: Icons.document_scanner_rounded,
            backgroundColor: Colors.teal.shade700,
          );
        }
      }
    } catch (e) {
      debugPrint('[DOC_SCANNER_HATA] $e');
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: 'Tarama iptal edildi veya bir hata oluştu.',
        icon: Icons.info_outline_rounded,
        backgroundColor: Colors.amber.shade900,
      );
    }
  }

  Future<void> _handleSnippetOcr() async {
    HapticFeedback.lightImpact();
    final File? txtResult = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => const SnippetOcrScreen()),
    );

    if (txtResult != null && mounted) {
      _home.addResult(txtResult);
      showFeedbackSnackBar(
        context,
        message: 'Kırpılan metin TXT olarak kaydedildi!',
        icon: Icons.text_snippet_rounded,
        backgroundColor: Colors.teal.shade700,
      );
    }
  }

  Future<void> _handleCreateZip() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) {
      await FilePicker.platform.clearTemporaryFiles();
      return;
    }

    final files = result.files
        .where((file) => file.path != null)
        .map((file) => File(file.path!))
        .toList();

    if (files.isEmpty) {
      await FilePicker.platform.clearTemporaryFiles();
      return;
    }

    const int maxBytes = 1800 * 1024 * 1024;
    final tooLarge = files.where((f) => f.existsSync() && f.lengthSync() > maxBytes).toList();
    if (tooLarge.isNotEmpty) {
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: 'Tek bir dosya 1.8 GB sınırını aşamaz!',
        icon: Icons.warning_amber_rounded,
        backgroundColor: Colors.amber.shade900,
      );
      await FilePicker.platform.clearTemporaryFiles();
      return;
    }

    try {
      final op = await _home.createZip(files);
      _notify(op);
    } finally {
      await FilePicker.platform.clearTemporaryFiles();
    }
  }

  Future<void> _previewFile(File file) async {
    HapticFeedback.lightImpact();
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && mounted) {
      showFeedbackSnackBar(
        context,
        message: 'Dosya açılamadı: ${result.message}',
        icon: Icons.broken_image_rounded,
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  Future<void> _backupSingleFileToDrive(File file) async {
    final op = await _home.backupSingleToDrive(file);
    if (!mounted) return;
    showFeedbackSnackBar(
      context,
      message: op.message,
      icon: op.isSuccess ? Icons.cloud_done_rounded : Icons.lock_outline_rounded,
      backgroundColor: op.isSuccess ? Colors.green.shade700 : Colors.amber.shade900,
    );
  }

  Future<void> _backupToGoogleDrive() async {
    final op = await _home.backupAllToDrive();
    if (!mounted) return;
    showFeedbackSnackBar(
      context,
      message: op.message,
      icon: op.isSuccess ? Icons.cloud_done_rounded : Icons.lock_outline_rounded,
      backgroundColor: op.isSuccess ? Colors.teal.shade700 : Colors.amber.shade900,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final home = context.watch<HomeViewModel>();
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();
    final busy = home.busy;
    final resultFiles = home.resultFiles;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 1,
                backgroundColor: theme.scaffoldBackgroundColor,
                title: Text(
                  'Dosya Stüdyosu',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  Consumer<ThemeViewModel>(
                    builder: (context, themeViewModel, _) => IconButton(
                      tooltip: themeViewModel.isDark ? 'Açık Tema' : 'Koyu Tema',
                      icon: Icon(
                        themeViewModel.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 20,
                      ),
                      onPressed: themeViewModel.toggle,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Seçenekler',
                    icon: const Icon(Icons.more_vert_rounded),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (value) {
                      if (value == 'key') {
                        showApiKeyDialog(context);
                      } else if (value == 'logout') {
                        home.signOut();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'key',
                        child: Row(
                          children: [
                            Icon(Icons.key_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Deepgram API Anahtarı'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 20, color: Colors.red.shade400),
                            const SizedBox(width: 12),
                            Text('Çıkış Yap', style: TextStyle(color: Colors.red.shade400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Bulut / Hesap Durum Şeridi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _buildAccountStatusHeader(context, googleAuth, msAuth),
                ),
              ),

              // 1. BÖLÜM: Ana Hızlı Araçlar (İkili Hero Düzen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHeroActionCard(
                          context,
                          title: 'Ses ➔ Metin',
                          subtitle: 'Nova-2 AI Transkripsiyon',
                          icon: Icons.graphic_eq_rounded,
                          color: Colors.deepOrangeAccent,
                          onTap: _handleAudioToText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildHeroActionCard(
                          context,
                          title: 'PC Paylaş',
                          subtitle: 'Wi-Fi / QR Kod Aktarım',
                          icon: Icons.qr_code_2_rounded,
                          color: Colors.teal,
                          onTap: _handleDirectQrSend,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. BÖLÜM: Akıllı Tarama & OCR Hub'ı (Belge Tara + Alan Seçmeli Metin Çıkar)
              SliverToBoxAdapter(
                child: _buildSectionLabel('Akıllı Tarama & Metin Çıkarma (OCR)', Icons.document_scanner_rounded, Colors.deepPurple),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGroupedCard(
                    colorScheme: colorScheme,
                    child: Row(
                      children: [
                        // Kamera ile Sayfayı PDF Yap
                        Expanded(
                          child: _buildSubToolItem(
                            title: 'Belge Tara',
                            subtitle: 'Kamera ➔ A4 PDF yap',
                            icon: Icons.document_scanner_rounded,
                            iconColor: Colors.deepPurple,
                            onTap: _handleDocScanner,
                          ),
                        ),
                        Container(width: 1, height: 48, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                        // Görselden Alan Kırparak Metin Al
                        Expanded(
                          child: _buildSubToolItem(
                            title: 'Metin Çıkar (OCR)',
                            subtitle: 'Kutudan yazı kopyala',
                            icon: Icons.crop_free_rounded,
                            iconColor: Colors.teal.shade700,
                            onTap: _handleSnippetOcr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. BÖLÜM: PDF Araçları (Birleştir & Ayıkla)
              SliverToBoxAdapter(
                child: _buildSectionLabel('PDF & Belge Araçları', Icons.picture_as_pdf_rounded, Colors.purple),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGroupedCard(
                    colorScheme: colorScheme,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSubToolItem(
                            title: 'PDF Düzenleyici',
                            subtitle: 'Birleştir & Sayfa Ayıkla',
                            icon: Icons.auto_awesome_motion_rounded,
                            iconColor: Colors.deepOrange,
                            onTap: () async {
                              final File? result = await Navigator.push<File>(
                                context,
                                MaterialPageRoute(builder: (context) => const PdfStudioScreen()),
                              );
                              if (result != null && mounted) _home.addResult(result);
                            },
                          ),
                        ),
                        Container(width: 1, height: 48, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                        Expanded(
                          child: _buildSubToolItem(
                            title: 'Resim ➔ PDF',
                            subtitle: 'Görselleri PDF\'e çevir',
                            icon: Icons.collections_rounded,
                            iconColor: Colors.purple,
                            onTap: () async {
                              final File? singlePdf = await Navigator.push<File>(
                                context,
                                MaterialPageRoute(builder: (context) => const ImageToPdfScreen()),
                              );
                              if (singlePdf == null || !mounted) return;
                              _home.addResult(singlePdf);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. BÖLÜM: Office Dönüştürücü Hub'ı
              SliverToBoxAdapter(
                child: _buildSectionLabel('Office Belgeleri ➔ PDF', Icons.description_rounded, const Color(0xFF185ABD)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGroupedCard(
                    colorScheme: colorScheme,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildOfficePill(
                              title: 'Word',
                              ext: '.docx / .doc',
                              icon: Icons.article_rounded,
                              color: const Color(0xFF185ABD),
                              onTap: () => _processCategory(
                                extensions: ['docx', 'doc'],
                                kind: ConversionKind.office,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildOfficePill(
                              title: 'Excel',
                              ext: '.xlsx / .xls',
                              icon: Icons.table_chart_rounded,
                              color: const Color(0xFF107C41),
                              onTap: () => _processCategory(
                                extensions: ['xlsx', 'xls'],
                                kind: ConversionKind.office,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildOfficePill(
                              title: 'PowerPoint',
                              ext: '.pptx / .ppt',
                              icon: Icons.slideshow_rounded,
                              color: const Color(0xFFC43E1C),
                              onTap: () => _processCategory(
                                extensions: ['pptx', 'ppt'],
                                kind: ConversionKind.office,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 5. BÖLÜM: Arşiv (ZIP) Araçları
              SliverToBoxAdapter(
                child: _buildSectionLabel('Arşivleme (ZIP)', Icons.folder_zip_rounded, Colors.brown),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGroupedCard(
                    colorScheme: colorScheme,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSubToolItem(
                            title: 'ZIP Oluştur',
                            subtitle: 'Dosyaları sıkıştır',
                            icon: Icons.archive_rounded,
                            iconColor: Colors.brown.shade700,
                            onTap: _handleCreateZip,
                          ),
                        ),
                        Container(width: 1, height: 48, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                        Expanded(
                          child: _buildSubToolItem(
                            title: 'ZIP Ayıkla',
                            subtitle: 'Klasöre çıkart',
                            icon: Icons.unarchive_rounded,
                            iconColor: Colors.amber.shade800,
                            onTap: () => _processCategory(
                              extensions: ['zip'],
                              kind: ConversionKind.zip,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 6. BÖLÜM: Hazır Dosyalar Listesi
              if (resultFiles.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Hazır Dosyalar (${resultFiles.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Tümünü Temizle',
                          icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                          color: Colors.red.shade400,
                          onPressed: busy ? null : _home.clearAllResults,
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: const Text('Yedekle', style: TextStyle(fontSize: 12)),
                          onPressed: busy ? null : _backupToGoogleDrive,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Tümünü Paylaş',
                          icon: const Icon(Icons.share_rounded, size: 16),
                          onPressed: busy ? null : home.shareAll,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildResultTile(resultFiles[index], colorScheme, theme),
                      childCount: resultFiles.length,
                    ),
                  ),
                ),
              ] else ...[
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ],
          ),
          ConversionProgressOverlay(
            isVisible: busy,
            title: home.statusMessage ?? 'İşleniyor...',
            currentFile: home.currentFileName,
            progress: home.progress,
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI BİLEŞENLER ---

  Widget _buildSectionLabel(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard({required ColorScheme colorScheme, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildHeroActionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: context.watch<HomeViewModel>().busy ? null : onTap,
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubToolItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: context.watch<HomeViewModel>().busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficePill({
    required String title,
    required String ext,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: context.watch<HomeViewModel>().busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
            Text(
              ext,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStatusHeader(
      BuildContext context,
      GoogleAuthService googleAuth,
      MicrosoftAuthService msAuth,
      ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMs = msAuth.isSignedIn;
    final isGoogle = googleAuth.isSignedIn;

    final title = isMs
        ? 'Microsoft Hesabı Aktif'
        : (isGoogle ? (googleAuth.currentUser?.email ?? 'Google Hesabı Aktif') : 'Misafir Modu');

    final color = isMs ? const Color(0xFF0078D4) : (isGoogle ? Colors.green.shade700 : colorScheme.outline);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              isMs ? Icons.window_rounded : (isGoogle ? Icons.account_circle_rounded : Icons.cloud_off_rounded),
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            isMs || isGoogle ? 'Bulut Senkronize' : 'Yerel Hafıza',
            style: TextStyle(fontSize: 10.5, color: colorScheme.outline, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(File file, ColorScheme colorScheme, ThemeData theme) {
    final fileName = file.uri.pathSegments.last;
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final isTxt = fileName.toLowerCase().endsWith('.txt');
    final fileSizeKB = (file.existsSync() ? file.lengthSync() / 1024 : 0).toStringAsFixed(1);

    Color badgeColor = colorScheme.primaryContainer;
    Color iconColor = colorScheme.primary;
    IconData fileIcon = Icons.insert_drive_file_rounded;

    if (isPdf) {
      badgeColor = Colors.red.withValues(alpha: 0.1);
      iconColor = Colors.red.shade700;
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (isTxt) {
      badgeColor = Colors.deepOrange.withValues(alpha: 0.1);
      iconColor = Colors.deepOrange.shade700;
      fileIcon = Icons.description_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          onTap: () => _previewFile(file),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(fileIcon, color: iconColor, size: 18),
          ),
          title: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '$fileSizeKB KB • Önizlemek için dokunun',
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Paylaş',
                icon: const Icon(Icons.share_rounded, size: 18),
                color: Colors.blue.shade600,
                onPressed: () => _shareSingleFile(file),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'QR Paylaş',
                icon: const Icon(Icons.qr_code_rounded, size: 18),
                color: Colors.teal.shade700,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QrShareScreen(file: file)),
                  );
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Drive\'a Yükle',
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                color: Colors.indigo.shade700,
                onPressed: context.watch<HomeViewModel>().busy ? null : () => _backupSingleFileToDrive(file),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: Colors.red.shade400,
                onPressed: () => _home.removeResult(file),
              ),
            ],
          ),
        ),
      ),
    );
  }
}