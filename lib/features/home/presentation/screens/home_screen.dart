import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import 'package:dosya_converter/core/widgets/coversion_progress_overlay.dart';
import 'package:dosya_converter/core/files/temp_file_manager.dart';
import '../../../../core/theme/theme_view_model.dart';
import '../../../../core/widgets/feedback_snack_bar.dart';
import '../../../auth/data/google_auth_service.dart';
import '../../../auth/data/microsoft_auth_service.dart';
import '../../../convert/domain/conversion_kind.dart';
import '../../../convert/presentation/screens/image_to_pdf_screen.dart';
import '../../../pdf_tools/presentation/screens/pdf_compress_screen.dart';
import '../../../pdf_tools/presentation/screens/pdf_merge_screen.dart';
import '../../../pdf_tools/presentation/screens/pdf_split_screen.dart';
import '../../../scanner/presentation/screens/doc_scanner_screen.dart';
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
      icon: result.isSuccess
          ? Icons.check_circle_rounded
          : Icons.error_outline_rounded,
      backgroundColor:
      result.isSuccess ? Colors.teal.shade700 : Colors.red.shade800,
    );
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
      icon: op.isSuccess
          ? Icons.cloud_done_rounded
          : Icons.lock_outline_rounded,
      backgroundColor:
      op.isSuccess ? Colors.green.shade700 : Colors.amber.shade900,
    );
  }

  Future<void> _handlePdfCompression() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: false,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      await FilePicker.platform.clearTemporaryFiles();
      return;
    }
    if (!mounted) return;

    final selectedPdf = File(result.files.single.path!);
    File? compressed;
    try {
      compressed = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (context) => PdfCompressScreen(file: selectedPdf)),
      );
    } finally {
      await FilePicker.platform.clearTemporaryFiles();
    }

    if (compressed != null && mounted) {
      _home.addResult(compressed);
      showFeedbackSnackBar(
        context,
        message: 'Sıkıştırılmış PDF hazırlandı!',
        icon: Icons.compress_rounded,
        backgroundColor: Colors.teal.shade700,
      );
    }
  }

  Future<void> _handleDocScanner() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || !mounted) {
      return;
    }

    final imageFiles = pickedFiles.map((x) => File(x.path)).toList();
    File? outputPdf;
    try {
      outputPdf = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) => DocScannerScreen(initialImages: imageFiles),
        ),
      );
    } finally {
      await TempFileManager.deleteFiles(imageFiles);
    }

    if (outputPdf != null && mounted) {
      _home.addResult(outputPdf);
      showFeedbackSnackBar(
        context,
        message: 'Taranmış A4 PDF başarıyla oluşturuldu!',
        icon: Icons.document_scanner_rounded,
        backgroundColor: Colors.deepPurple.shade600,
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

  Future<void> _backupToGoogleDrive() async {
    final op = await _home.backupAllToDrive();
    if (!mounted) return;
    showFeedbackSnackBar(
      context,
      message: op.message,
      icon: op.isSuccess
          ? Icons.cloud_done_rounded
          : Icons.lock_outline_rounded,
      backgroundColor:
      op.isSuccess ? Colors.teal.shade700 : Colors.amber.shade900,
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
              // Modern, temiz ve göz yormayan App Bar
              SliverAppBar(
                floating: true,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 1,
                backgroundColor: theme.scaffoldBackgroundColor,
                title: Text(
                  'Dosya Dönüştürücü',
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
                        themeViewModel.isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 20,
                      ),
                      onPressed: themeViewModel.toggle,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Seçenekler',
                    icon: const Icon(Icons.more_vert_rounded),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                            Text('Groq API Anahtarı'),
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

              // Hesap Durumu
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildAccountStatusHeader(context, googleAuth, msAuth),
                ),
              ),

              // 1. BÖLÜM: Hızlı Araçlar (Dengeli 3'lü Yatay veya Şık 2x2)
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'Hızlı İşlemler',
                  icon: Icons.bolt_rounded,
                  color: Colors.amber.shade700,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildModernQuickAction(
                      context,
                      title: 'PC\'ye Paylaş',
                      subtitle: 'Wi-Fi / QR',
                      icon: Icons.qr_code_2_rounded,
                      color: Colors.teal,
                      onTap: _handleDirectQrSend,
                    ),
                    _buildModernQuickAction(
                      context,
                      title: 'Belge Tara',
                      subtitle: 'Kamera ➔ PDF',
                      icon: Icons.document_scanner_rounded,
                      color: Colors.deepPurple,
                      onTap: _handleDocScanner,
                    ),
                    _buildModernQuickAction(
                      context,
                      title: 'Ses ➔ Metin',
                      subtitle: 'Whisper AI',
                      icon: Icons.record_voice_over_rounded,
                      color: Colors.deepOrangeAccent,
                      onTap: _handleAudioToText,
                    ),
                  ]),
                ),
              ),

              // 2. BÖLÜM: Office Dönüştürücüler
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'Office Belgeleri ➔ PDF',
                  subtitle: 'Word, Excel ve PowerPoint dosyalarını PDF yapın',
                  icon: Icons.article_rounded,
                  color: const Color(0xFF185ABD),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildOfficeCard(
                      context,
                      title: 'Word',
                      extension: '.docx',
                      icon: Icons.description_rounded,
                      color: const Color(0xFF185ABD),
                      onTap: () => _processCategory(
                        extensions: ['docx', 'doc'],
                        kind: ConversionKind.office,
                      ),
                    ),
                    _buildOfficeCard(
                      context,
                      title: 'Excel',
                      extension: '.xlsx',
                      icon: Icons.table_chart_rounded,
                      color: const Color(0xFF107C41),
                      onTap: () => _processCategory(
                        extensions: ['xlsx', 'xls'],
                        kind: ConversionKind.office,
                      ),
                    ),
                    _buildOfficeCard(
                      context,
                      title: 'PowerPoint',
                      extension: '.pptx',
                      icon: Icons.slideshow_rounded,
                      color: const Color(0xFFC43E1C),
                      onTap: () => _processCategory(
                        extensions: ['pptx', 'ppt'],
                        kind: ConversionKind.office,
                      ),
                    ),
                  ]),
                ),
              ),

              // 3. BÖLÜM: PDF ve Arşiv Araçları
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'PDF & Arşiv Araçları',
                  icon: Icons.auto_awesome_mosaic_rounded,
                  color: Colors.purple.shade600,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildToolTile(
                      context,
                      title: 'Resim ➔ PDF',
                      subtitle: 'JPG / PNG birleştir',
                      icon: Icons.collections_rounded,
                      color: Colors.purple.shade600,
                      onTap: () async {
                        final File? singlePdf = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const ImageToPdfScreen()),
                        );
                        if (singlePdf == null || !mounted) return;
                        _home.addResult(singlePdf);
                      },
                    ),
                    _buildToolTile(
                      context,
                      title: 'PDF Birleştir',
                      subtitle: 'Tek dosya yap',
                      icon: Icons.merge_type_rounded,
                      color: Colors.deepOrange.shade600,
                      onTap: () async {
                        final File? merged = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const PdfMergeScreen()),
                        );
                        if (merged != null && mounted) _home.addResult(merged);
                      },
                    ),
                    _buildToolTile(
                      context,
                      title: 'Sayfa Ayıkla',
                      subtitle: 'PDF sayfalarını böl',
                      icon: Icons.call_split_rounded,
                      color: Colors.indigo.shade600,
                      onTap: () async {
                        final File? extracted = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const PdfSplitScreen()),
                        );
                        if (extracted != null && mounted) _home.addResult(extracted);
                      },
                    ),
                    _buildToolTile(
                      context,
                      title: 'PDF Küçült',
                      subtitle: 'Boyut sıkıştırma',
                      icon: Icons.compress_rounded,
                      color: Colors.blueGrey.shade700,
                      onTap: _handlePdfCompression,
                    ),
                    _buildToolTile(
                      context,
                      title: 'ZIP Oluştur',
                      subtitle: 'Dosyaları paketle',
                      icon: Icons.archive_rounded,
                      color: Colors.brown.shade600,
                      onTap: _handleCreateZip,
                    ),
                    _buildToolTile(
                      context,
                      title: 'ZIP Ayıkla',
                      subtitle: 'Dışarı çıkart',
                      icon: Icons.folder_zip_rounded,
                      color: Colors.amber.shade800,
                      onTap: () => _processCategory(
                        extensions: ['zip'],
                        kind: ConversionKind.zip,
                      ),
                    ),
                  ]),
                ),
              ),

              // 4. BÖLÜM: Hazır Dosyalar Listesi
              if (resultFiles.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 50),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                          _buildResultTile(resultFiles[index], colorScheme, theme),
                      childCount: resultFiles.length,
                    ),
                  ),
                ),
              ] else ...[
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
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

  Widget _buildAccountStatusHeader(
      BuildContext context,
      GoogleAuthService googleAuth,
      MicrosoftAuthService msAuth,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMs = msAuth.isSignedIn;
    final isGoogle = googleAuth.isSignedIn;

    final title = isMs
        ? 'Microsoft Hesabı Bağlı'
        : (isGoogle
        ? (googleAuth.currentUser?.email ?? 'Google Hesabı Bağlı')
        : 'Misafir Modu');

    final color = isMs
        ? const Color(0xFF0078D4)
        : (isGoogle ? Colors.green.shade700 : colorScheme.outline);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              isMs
                  ? Icons.window_rounded
                  : (isGoogle ? Icons.account_circle_rounded : Icons.cloud_off_rounded),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isMs || isGoogle
                      ? 'Bulut yedekleme hazır'
                      : 'Yerel modda çalışıyor',
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Max 10 Dosya',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, {
        required String title,
        String? subtitle,
        required IconData icon,
        required Color color,
      }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernQuickAction(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: context.watch<HomeViewModel>().busy ? null : onTap,
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeCard(
      BuildContext context, {
        required String title,
        required String extension,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: context.watch<HomeViewModel>().busy ? null : onTap,
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                extension,
                style: TextStyle(fontSize: 10, color: colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: context.watch<HomeViewModel>().busy ? null : onTap,
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colorScheme.outline),
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              fileIcon,
              color: iconColor,
              size: 20,
            ),
          ),
          title: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '$fileSizeKB KB • Dokun ve Gör',
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
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
                tooltip: 'Drive\'a Yükle',
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                color: Colors.blue.shade700,
                onPressed: context.watch<HomeViewModel>().busy
                    ? null
                    : () => _backupSingleFileToDrive(file),
              ),
              IconButton(
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