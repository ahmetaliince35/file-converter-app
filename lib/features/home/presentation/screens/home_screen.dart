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
    debugPrint('====================================');
    debugPrint('[DEBUG 1] Butona basildi, secici aciliyor...');
    HapticFeedback.selectionClick();

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result == null || result.files.isEmpty) {
      debugPrint('[DEBUG 2] Secim iptal edildi.');
      return;
    }

    final rawPath = result.files.single.path;
    debugPrint('[DEBUG 3] Secilen Ham Yol: $rawPath');

    if (rawPath != null) {
      final f = File(rawPath);
      final exists = await f.exists();
      debugPrint('[DEBUG 4] Dosya Secildigi An Diskte Var Mi?: $exists');
      if (exists) {
        debugPrint('[DEBUG 5] Dosya Boyutu: ${await f.length()} bayt');
      }
    }

    final validFiles = result.files
        .where((file) => file.path != null)
        .map((file) => File(file.path!))
        .toList();

    debugPrint('[DEBUG 6] ViewModel\'e gonderiliyor... Dosya sayisi: ${validFiles.length}');

    try {
      final op = await _home.processFiles(files: validFiles, kind: kind);
      debugPrint('[DEBUG 7] ViewModel Sonucu: ${op.message} (Basari: ${op.isSuccess})');
      _notify(op);
    } catch (e, stack) {
      debugPrint('[DEBUG HATA YAKALANDI] Tur: $e');
      debugPrint('[DEBUG STACK TRACE]:\n$stack');
    }
    debugPrint('====================================');
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
      // Ham kamera kopyalarını sil:
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
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: const Text(
                  'Dönüştürücü Paneli',
                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                actions: [
                  Consumer<ThemeViewModel>(
                    builder: (context, themeViewModel, _) => IconButton(
                      tooltip: themeViewModel.isDark ? 'Açık temaya geç' : 'Koyu temaya geç',
                      icon: Icon(
                        themeViewModel.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      ),
                      onPressed: themeViewModel.toggle,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'QR ile Dosya Paylaş',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: busy ? null : _handleDirectQrSend,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Çıkış Yap',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: home.signOut,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildAccountStatusHeader(context, googleAuth, msAuth),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'Öne Çıkanlar & Hızlı Erişim',
                  icon: Icons.bolt_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildFeatureCard(
                      title: 'PC\'ye Gönder',
                      subtitle: 'Wi-Fi / QR Drop',
                      icon: Icons.qr_code_2_rounded,
                      accentColor: Colors.teal,
                      onTap: _handleDirectQrSend,
                    ),
                    _buildFeatureCard(
                      title: 'Belge Tara',
                      subtitle: 'Kameradan A4 PDF',
                      icon: Icons.document_scanner_rounded,
                      accentColor: Colors.deepPurple,
                      onTap: _handleDocScanner,
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'Office Belgeleri( Word, Excel, Powerpoint ) ⮕ PDF',
                  subtitle: 'Kusursuz dönüşüm için Microsoft hesabı ile giriş önerilir.',
                  icon: Icons.cloud_sync_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildCompactActionCard(
                      title: 'Word',
                      extension: '.docx',
                      icon: Icons.description_rounded,
                      color: const Color(0xFF185ABD),
                      onTap: () => _processCategory(
                        extensions: ['docx', 'doc'],
                        kind: ConversionKind.office,
                      ),
                    ),
                    _buildCompactActionCard(
                      title: 'Excel',
                      extension: '.xlsx',
                      icon: Icons.table_chart_rounded,
                      color: const Color(0xFF107C41),
                      onTap: () => _processCategory(
                        extensions: ['xlsx', 'xls'],
                        kind: ConversionKind.office,
                      ),
                    ),
                    _buildCompactActionCard(
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
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'PDF ve Arşiv Araçları',
                  icon: Icons.build_circle_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildFeatureCard(
                      title: 'Resim ⮕ PDF',
                      subtitle: 'JPG / PNG derle',
                      icon: Icons.collections_rounded,
                      accentColor: Colors.purple.shade600,
                      onTap: () async {
                        final File? singlePdf = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const ImageToPdfScreen()),
                        );
                        if (singlePdf == null || !mounted) return;
                        _home.addResult(singlePdf);
                        showFeedbackSnackBar(
                          context,
                          message: 'Resimler PDF yapıldı!',
                          icon: Icons.check_circle_rounded,
                          backgroundColor: Colors.purple.shade700,
                        );
                      },
                    ),
                    _buildFeatureCard(
                      title: 'PDF Birleştir',
                      subtitle: 'Dosyaları bağla',
                      icon: Icons.merge_type_rounded,
                      accentColor: Colors.deepOrange.shade600,
                      onTap: () async {
                        final File? merged = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const PdfMergeScreen()),
                        );
                        if (merged != null && mounted) {
                          _home.addResult(merged);
                        }
                      },
                    ),
                    _buildFeatureCard(
                      title: 'PDF Sayfa Ayıkla',
                      subtitle: 'İstediğin sayfaları böl',
                      icon: Icons.call_split_rounded,
                      accentColor: Colors.indigo.shade600,
                      onTap: () async {
                        final File? extracted = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const PdfSplitScreen()),
                        );
                        if (extracted != null && mounted) {
                          _home.addResult(extracted);
                        }
                      },
                    ),
                    _buildFeatureCard(
                      title: 'PDF Küçült',
                      subtitle: 'Boyut optimizasyonu',
                      icon: Icons.compress_rounded,
                      accentColor: Colors.blueGrey.shade700,
                      onTap: _handlePdfCompression,
                    ),
                    _buildFeatureCard(
                      title: 'ZIP Oluştur',
                      subtitle: 'Dosyaları paketle',
                      icon: Icons.archive_rounded,
                      accentColor: Colors.brown.shade600,
                      onTap: _handleCreateZip,
                    ),
                    _buildFeatureCard(
                      title: 'ZIP Ayıkla',
                      subtitle: 'Arşivden çıkart',
                      icon: Icons.folder_zip_rounded,
                      accentColor: Colors.amber.shade800,
                      onTap: () => _processCategory(
                        extensions: ['zip'],
                        kind: ConversionKind.zip,
                      ),
                    ),
                  ]),
                ),
              ),
              if (resultFiles.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Hazır Dosyalar (${resultFiles.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: const Text('Tümünü Yedekle'),
                          onPressed: busy ? null : _backupToGoogleDrive,
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Tümünü Paylaş',
                          icon: const Icon(Icons.share_rounded, size: 18),
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
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
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
        : (isGoogle ? (googleAuth.currentUser?.email ?? 'Google Hesabı Bağlı') : 'Misafir / Çevrimdışı Mod');

    final color = isMs
        ? const Color(0xFF0078D4)
        : (isGoogle ? Colors.green.shade700 : colorScheme.outline);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              isMs
                  ? Icons.window_rounded
                  : (isGoogle ? Icons.account_circle_rounded : Icons.person_outline_rounded),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isMs || isGoogle ? 'Bulut entegrasyonu aktif' : 'Giriş yaparak Drive/MS özelliklerini açın',
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Max 10 Dosya',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
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
        String? subtitle, // <-- Alt başlık parametresi
        required IconData icon,
      }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26), // İkonun hizasına denk getirdik
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: context.watch<HomeViewModel>().busy ? null : onTap,
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
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

  Widget _buildCompactActionCard({
    required String title,
    required String extension,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
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
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                extension,
                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
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
    final fileSizeKB = (file.existsSync() ? file.lengthSync() / 1024 : 0).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          onTap: () => _previewFile(file),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPdf ? Colors.red.withValues(alpha: 0.1) : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              color: isPdf ? Colors.red.shade700 : colorScheme.primary,
              size: 22,
            ),
          ),
          title: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '$fileSizeKB KB • Dokun ve Görüntüle',
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'QR ile PC\'ye Aktar',
                icon: const Icon(Icons.qr_code_rounded, size: 20),
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
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                color: Colors.blue.shade700,
                onPressed: context.watch<HomeViewModel>().busy
                    ? null
                    : () => _backupSingleFileToDrive(file),
              ),
              IconButton(
                tooltip: 'Listeden ve Diskten Sil',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
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