import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_view_model.dart';
import '../../../../core/widgets/coversion_progress_overlay.dart';
import '../../../../core/widgets/feedback_snack_bar.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../convert/data/universal_converter_service.dart';
import '../../../convert/data/zip_archive_service.dart';
import '../../../convert/domain/conversion_kind.dart';
import '../../../convert/presentation/screens/image_to_pdf_screen.dart';
import '../../../convert/presentation/screens/universal_converter_screen.dart';
import '../../../convert/presentation/widgets/zip_file_picker_sheet.dart';
import '../../../ocr/presentation/snippet_ocr_screen.dart';
import '../../../pdf_tools/presentation/pdf_studio_screen.dart';
import '../../../share/presentation/screens/qr_share_screen.dart';
import '../../../transcribe/data/audio_to_text_converter.dart';
import '../../../transcribe/presentation/audio_to_text_screen.dart';
import '../../../transcribe/presentation/widget/api_key_dialog.dart';
import '../../data/services/file_selector_service.dart';
import '../../domain/models/processed_file_item.dart';
import '../view_models/home_view_model.dart';
import '../widgets/account_badge_header.dart';
import '../widgets/code_viewer_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeViewModel get _home => context.read<HomeViewModel>();

  void _notify(HomeOpResult? result) {
    if (result == null || !mounted) return;
    showFeedbackSnackBar(
      context,
      message: result.message,
      icon: result.isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      backgroundColor: result.isSuccess ? const Color(0xFF4E8772) : const Color(0xFFC46B6B),
    );
  }

  // --- HIZLI EYLEMLER ---

  Future<void> _handleDirectQrSend() async {
    const fileSelector = FileSelectorService();
    final result = await fileSelector.pickAnyFiles(
      allowMultiple: false,
      maxSizeBytes: 1024 * 1024 * 1024, // 1 GB
    );

    if (result.isCancelled) return;
    if (result.hasError) {
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: result.errorMessage!,
        icon: Icons.warning_amber_rounded,
        backgroundColor: const Color(0xFFC88A3A),
      );
      return;
    }

    if (!mounted || result.files.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrShareScreen(file: result.files.first)),
    );
  }

  Future<void> _handleAudioToText() async {
    final apiKey = await AudioToTextConverter.getSavedApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      showApiKeyDialog(context, onSaved: () {
        if (mounted) _openAudioToTextScreen();
      });
      return;
    }
    await _openAudioToTextScreen();
  }

  Future<void> _openAudioToTextScreen() async {
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
        backgroundColor: const Color(0xFF4E8772),
      );
    }
  }

  // --- EVRENSEL DÖNÜŞTÜRÜCÜ ---

  Future<void> _handleUniversalToPdf() async {
    await _handleUniversalConversion(UniversalTargetFormat.pdf);
  }

  Future<void> _handleUniversalToTxt() async {
    await _handleUniversalConversion(UniversalTargetFormat.txt);
  }

  Future<void> _handleUniversalConversion(UniversalTargetFormat defaultTarget) async {
    const fileSelector = FileSelectorService();
    final selection = await fileSelector.pickUniversalFiles(allowMultiple: true);
    if (selection.isCancelled || selection.files.isEmpty) return;
    if (selection.hasError) {
      _notify(HomeOpResult.failure(selection.errorMessage!));
      return;
    }

    final normalFiles = <File>[];
    final zipFiles = <File>[];

    for (final file in selection.files) {
      if (p.extension(file.path).toLowerCase() == '.zip') {
        zipFiles.add(file);
      } else {
        normalFiles.add(file);
      }
    }

    // Normal belgeleri doğrudan dönüştür
    if (normalFiles.isNotEmpty) {
      final op = await _home.convertUniversalFiles(
        files: normalFiles,
        targetFormat: defaultTarget,
      );
      _notify(op);
    }

    // ZIP arşivleri için panel açarak seçtir
    for (final zipFile in zipFiles) {
      if (!mounted) return;
      await _processZipFile(zipFile, defaultTarget);
    }
  }

  Future<void> _processZipFile(File zipFile, UniversalTargetFormat defaultTarget) async {
    const zipService = ZipArchiveService();
    List<ZipEntryItem> entries;
    try {
      entries = await zipService.inspectZip(zipFile);
    } catch (e) {
      if (mounted) {
        _notify(HomeOpResult.failure('ZIP arşivi okunamadı: $e'));
      }
      return;
    }

    final convertible = entries.where((e) => e.isConvertible).toList();
    if (convertible.isEmpty) {
      if (mounted) {
        _notify(const HomeOpResult.failure(
          'Arşiv içinde dönüştürülebilir belge bulunamadı (ses, video ve resimler hariçtir).',
        ));
      }
      return;
    }

    if (!mounted) return;
    final req = await ZipFilePickerSheet.show(
      context,
      zipFile: zipFile,
      entries: entries,
      isExtractOnly: false,
      defaultTarget: defaultTarget,
    );

    if (req == null || req.selectedPaths.isEmpty) return;

    try {
      final extracted = await zipService.extractSelectedFiles(
        zipFile: zipFile,
        selectedPaths: req.selectedPaths,
      );

      if (extracted.isEmpty) {
        if (mounted) {
          _notify(const HomeOpResult.failure('Dosyalar arşivden çıkartılamadı.'));
        }
        return;
      }

      final op = await _home.convertUniversalFiles(
        files: extracted,
        targetFormat: req.targetFormat ?? defaultTarget,
      );
      _notify(op);
    } catch (e) {
      if (mounted) {
        _notify(HomeOpResult.failure('ZIP dönüştürme hatası: $e'));
      }
    }
  }

  void _openUniversalStudio() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UniversalConverterScreen()),
    );
  }

  void _showConvertChooser() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Dosya Dönüştür',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC46B6B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFC46B6B), size: 20),
                ),
                title: const Text('PDF Formatına Dönüştür', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Word, Excel, Kod ve Metinleri PDF yapar', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleUniversalToPdf();
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A373).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.text_snippet_rounded, color: Color(0xFFD4A373), size: 20),
                ),
                title: const Text('TXT Formatına Dönüştür', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Belgelerdeki metin içeriğini sade TXT yapar', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleUniversalToTxt();
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B72B8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6B72B8), size: 20),
                ),
                title: const Text('Gelişmiş Dönüştürücü Stüdyosu', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Önizleme ve toplu dönüştürme paneli', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openUniversalStudio();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TARAMA VE OCR ---

  Future<void> _handleDocScanner() async {
    final op = await _home.scanDocument();
    _notify(op);
  }

  Future<void> _handleSnippetOcr() async {
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
        backgroundColor: const Color(0xFF4E8772),
      );
    }
  }

  void _showScanMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Belge Tarama & Metin Çıkarma',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5A7BA6).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF5A7BA6), size: 20),
                ),
                title: const Text('Belge Tara (Kamera)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Fotoğraf çekerek A4 PDF belgesi oluşturun', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDocScanner();
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B72B8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.crop_free_rounded, color: Color(0xFF6B72B8), size: 20),
                ),
                title: const Text('Bölgesel Metin Çıkar (OCR)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Fotoğraftaki seçtiğiniz yazıyı metne çevirin', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSnippetOcr();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- OFFICE İŞLEMLERİ (WORD, EXCEL, PPT) ---

  void _showOfficeMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Office İşlemleri',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A7C9F).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article_rounded, color: Color(0xFF4A7C9F), size: 20),
                ),
                title: const Text('Word ➔ PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('.docx ve .doc belgelerini PDF formatına dönüştürün', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processCategory(
                    extensions: ['docx', 'doc'],
                    kind: ConversionKind.office,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E8772).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFF4E8772), size: 20),
                ),
                title: const Text('Excel ➔ PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('.xlsx ve .xls tablolarını PDF formatına dönüştürün', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processCategory(
                    extensions: ['xlsx', 'xls'],
                    kind: ConversionKind.office,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC88A58).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.slideshow_rounded, color: Color(0xFFC88A58), size: 20),
                ),
                title: const Text('PowerPoint ➔ PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('.pptx ve .ppt sunumlarını PDF formatına dönüştürün', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _processCategory(
                    extensions: ['pptx', 'ppt'],
                    kind: ConversionKind.office,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCategory({
    required List<String> extensions,
    required ConversionKind kind,
  }) async {
    final op = await _home.pickAndConvertCategory(extensions: extensions, kind: kind);
    _notify(op);
  }

  // --- PDF ARAÇLARI ---

  Future<void> _handlePdfStudio({int initialTabIndex = 0}) async {
    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => PdfStudioScreen(initialTabIndex: initialTabIndex),
      ),
    );
    if (result != null && mounted) {
      _home.addResult(result);
    }
  }

  Future<void> _handleImagesToPdf() async {
    final File? singlePdf = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => const ImageToPdfScreen()),
    );
    if (singlePdf != null && mounted) {
      _home.addResult(singlePdf);
    }
  }

  void _showPdfMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PDF Stüdyo & Düzenleme',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC46B6B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_motion_rounded, color: Color(0xFFC46B6B), size: 20),
                ),
                title: const Text('PDF Birleştir', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Birden fazla PDF belgesini tek dosyada birleştirin', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePdfStudio(initialTabIndex: 0);
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05656).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.call_split_rounded, color: Color(0xFFE05656), size: 20),
                ),
                title: const Text('PDF Sayfa Ayıkla & Böl', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('PDF içinden dilediğiniz sayfaları seçip yeni PDF yapın', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePdfStudio(initialTabIndex: 1);
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E72AF).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF7E72AF), size: 20),
                ),
                title: const Text('Resimleri PDF Yap', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Fotoğrafları A4 matris düzeninde PDF\'e çevirin', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImagesToPdf();
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E6AD2).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF5E6AD2), size: 20),
                ),
                title: const Text('Belgeleri PDF\'e Dönüştür', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Word, Excel, Kod ve Metinleri PDF yapın', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleUniversalToPdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DİĞER ARAÇLAR MENÜSÜ ---

  void _showZipMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'ZIP Arşiv İşlemleri',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E8772).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.unarchive_rounded, color: Color(0xFF4E8772), size: 20),
                ),
                title: const Text('ZIP Arşivini Ayıkla', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Arşivdeki dosyaları orijinal haliyle dışarı çıkartın', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSafeExtractZip();
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC88A3A).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_zip_rounded, color: Color(0xFFC88A3A), size: 20),
                ),
                title: const Text('Yeni ZIP Arşivi Oluştur', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Seçtiğiniz dosyaları tek bir ZIP paketinde toplayın', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateZip();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateZip() async {
    final op = await _home.pickAndCreateZip();
    _notify(op);
  }

  Future<void> _handleSafeExtractZip() async {
    const fileSelector = FileSelectorService();
    final selection = await fileSelector.pickCategoryFiles(extensions: ['zip']);
    if (selection.isCancelled || selection.files.isEmpty) return;
    if (selection.hasError) {
      _notify(HomeOpResult.failure(selection.errorMessage!));
      return;
    }

    final zipFile = selection.files.first;
    const zipService = ZipArchiveService();
    List<ZipEntryItem> entries;
    try {
      entries = await zipService.inspectZip(zipFile);
    } catch (e) {
      if (mounted) {
        _notify(HomeOpResult.failure('ZIP arşivi okunamadı: $e'));
      }
      return;
    }

    if (entries.isEmpty) {
      if (mounted) {
        _notify(const HomeOpResult.failure('ZIP arşivi boş veya okunamadı.'));
      }
      return;
    }

    if (!mounted) return;
    final req = await ZipFilePickerSheet.show(
      context,
      zipFile: zipFile,
      entries: entries,
      isExtractOnly: true, // Sadece ayıklar, PDF zorunluluğu yok!
    );

    if (req == null || req.selectedPaths.isEmpty) return;

    try {
      final extracted = await zipService.extractSelectedFiles(
        zipFile: zipFile,
        selectedPaths: req.selectedPaths,
      );

      if (extracted.isEmpty) {
        if (mounted) {
          _notify(const HomeOpResult.failure('Dosyalar arşivden çıkartılamadı.'));
        }
        return;
      }

      for (final file in extracted) {
        _home.addResult(file);
      }

      if (mounted) {
        showFeedbackSnackBar(
          context,
          message: '${extracted.length} dosya arşivden başarıyla çıkartıldı!',
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF4E8772),
        );
      }
    } catch (e) {
      if (mounted) {
        _notify(HomeOpResult.failure('ZIP çıkarma hatası: $e'));
      }
    }
  }

  // --- DOSYA İŞLEMLERİ & MODAL MENÜ ---

  Future<void> _previewFile(File file) async {
    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    if (UniversalConverterService.isTextOrCodeExtension(ext)) {
      CodeViewerSheet.show(context, file);
      return;
    }

    final result = await _home.previewFile(file);
    if (!result.isSuccess && mounted) {
      showFeedbackSnackBar(
        context,
        message: result.message,
        icon: Icons.broken_image_rounded,
        backgroundColor: const Color(0xFFC46B6B),
      );
    }
  }

  void _showFileActions(ProcessedFileItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.typeLabel} • ${item.formattedSize}',
                            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.visibility_rounded, size: 20),
                title: const Text('Önizle / Aç', style: TextStyle(fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _previewFile(item.file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, size: 20),
                title: const Text('Paylaş', style: TextStyle(fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _home.shareSingle(item.file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded, size: 20),
                title: const Text('Dosya Paylaş (QR Kod)', style: TextStyle(fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QrShareScreen(file: item.file)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_rounded, size: 20),
                title: const Text('Google Drive\'a Yedekle', style: TextStyle(fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _backupSingleFileToDrive(item.file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC46B6B), size: 20),
                title: const Text('Listeden Sil', style: TextStyle(color: Color(0xFFC46B6B), fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _home.removeResult(item.file);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _backupSingleFileToDrive(File file) async {
    final op = await _home.backupSingleToDrive(file);
    _notify(op);
  }

  Future<void> _backupToGoogleDrive() async {
    final op = await _home.backupAllToDrive();
    _notify(op);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final home = context.watch<HomeViewModel>();
    final busy = home.busy;
    final results = home.filteredResults;
    final totalCount = home.resultItems.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF5E6AD2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_copy_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              'File++',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontSize: 19,
              ),
            ),
          ],
        ),
        actions: [
          // Tema Geçiş Düğmesi
          IconButton(
            tooltip: 'Tema',
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.read<ThemeViewModel>().toggle();
            },
          ),
          // Seçenekler Menüsü
          PopupMenuButton<String>(
            tooltip: 'Daha Fazla',
            icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) async {
              if (val == 'backup') {
                _backupToGoogleDrive();
              } else if (val == 'key') {
                showApiKeyDialog(context);
              } else if (val == 'login') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              } else if (val == 'logout') {
                await context.read<AuthViewModel>().completeSignOut();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'login',
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Hesap Girişi (Google & MS)', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Drive\'a Tümünü Yedekle', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'key',
                child: Row(
                  children: [
                    Icon(Icons.key_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Deepgram API Anahtarı', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Color(0xFFC46B6B)),
                    SizedBox(width: 10),
                    Text('Çıkış Yap', style: TextStyle(color: Color(0xFFC46B6B), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HESAP VE BULUT SENKRONİZASYON DURUMU (Login & Office Bağlantısı)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: AccountBadgeHeader(),
                ),
              ),

              // 1. ANA HERO ALANI: Yan Yana İki Eşit Kart (Dosya Dönüştür + Dosya Paylaş)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      // SOL KART: Dosya Dönüştür (Yarı Genişlik)
                      Expanded(
                        child: _HeroActionCard(
                          title: 'Dosya Dönüştür',
                          subtitle: 'PDF veya TXT yap',
                          icon: Icons.transform_rounded,
                          accentColor: const Color(0xFF5E6AD2),
                          onTap: busy ? () {} : _showConvertChooser,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // SAĞ KART: Dosya Paylaş (Yarı Genişlik)
                      Expanded(
                        child: _HeroActionCard(
                          title: 'Dosya Paylaş',
                          subtitle: 'Wi-Fi & QR Aktarım',
                          icon: Icons.qr_code_2_rounded,
                          accentColor: const Color(0xFF4E8772),
                          onTap: busy ? () {} : _handleDirectQrSend,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. TEMEL HIZLI ARAÇLAR: Tek Satırda 4 Sade İkon Butonu
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      _QuickToolButton(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Ses ➔ Metin',
                        color: const Color(0xFFC88A3A),
                        onTap: _handleAudioToText,
                      ),
                      const SizedBox(width: 8),
                      _QuickToolButton(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF Stüdyo',
                        color: const Color(0xFFC46B6B),
                        onTap: _showPdfMenu,
                      ),
                      const SizedBox(width: 8),
                      _QuickToolButton(
                        icon: Icons.document_scanner_rounded,
                        label: 'Tara & OCR',
                        color: const Color(0xFF5A7BA6),
                        onTap: _showScanMenu,
                      ),
                      const SizedBox(width: 8),
                      _QuickToolButton(
                        icon: Icons.business_center_rounded,
                        label: 'Office İşlemleri',
                        color: const Color(0xFF4A7C9F),
                        onTap: _showOfficeMenu,
                      ),
                    ],
                  ),
                ),
              ),

              // 2.1 İKİNCİL HIZLI ARAÇLAR: Görselleri PDF Yap & ZIP İşlemleri
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SecondaryActionCard(
                          icon: Icons.photo_library_rounded,
                          title: 'Görselleri PDF Yap',
                          subtitle: 'A4 Matris Düzeni',
                          accentColor: const Color(0xFF7E72AF),
                          onTap: _handleImagesToPdf,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SecondaryActionCard(
                          icon: Icons.folder_zip_rounded,
                          title: 'ZIP İşlemleri',
                          subtitle: 'Ayıkla & Paketle',
                          accentColor: const Color(0xFFC88A3A),
                          onTap: _showZipMenu,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. DÖNÜŞTÜRÜLEN DOSYALAR LİSTESİ
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Dönüştürülenler',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (totalCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (totalCount > 0)
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Tümünü Paylaş',
                              icon: const Icon(Icons.share_rounded, size: 17),
                              onPressed: home.shareAll,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Listeyi Temizle',
                              icon: const Icon(Icons.delete_sweep_rounded, size: 17),
                              onPressed: home.clearAllResults,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              if (totalCount == 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 38,
                            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Henüz dönüştürülen dosya yok',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = results[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MinimalFileRow(
                            item: item,
                            onTap: () => _previewFile(item.file),
                            onMoreTap: () => _showFileActions(item),
                          ),
                        );
                      },
                      childCount: results.length,
                    ),
                  ),
                ),
            ],
          ),

          // İŞLEM İLERLEME OVERLAY'İ
          ConversionProgressOverlay(
            isVisible: busy,
            title: 'Dönüştürülüyor...',
            currentFile: home.statusMessage ?? '',
            progress: home.progress,
          ),
        ],
      ),
    );
  }
}

/// Yarı Genişlikteki Yumuşak Hero Eylem Kartı (Dosya Dönüştür / Dosya Paylaş)
class _HeroActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _HeroActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sade ve Kompakt Hızlı Araç Düğmesi
class _QuickToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İkincil Araç Kartı (Görselleri PDF Yap & ZIP İşlemleri)
class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF161B26) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
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
}

/// Minimal, Tek Satır Dosya Elemanı
class _MinimalFileRow extends StatelessWidget {
  final ProcessedFileItem item;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _MinimalFileRow({
    required this.item,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
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
                  color: item.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.accentColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.typeLabel} • ${item.formattedSize}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: colorScheme.outline,
                  size: 19,
                ),
                onPressed: onMoreTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}