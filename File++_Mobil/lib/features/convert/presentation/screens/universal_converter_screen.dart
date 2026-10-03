import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dosya_converter/core/widgets/feedback_snack_bar.dart';
import 'package:dosya_converter/features/auth/data/google_auth_service.dart';
import 'package:dosya_converter/features/auth/data/microsoft_auth_service.dart';
import 'package:dosya_converter/features/convert/data/universal_converter_service.dart';
import 'package:dosya_converter/features/convert/data/zip_archive_service.dart';
import 'package:dosya_converter/features/convert/presentation/widgets/zip_file_picker_sheet.dart';
import 'package:dosya_converter/features/home/data/services/file_selector_service.dart';
import 'package:dosya_converter/features/home/presentation/view_models/home_view_model.dart';
import 'package:dosya_converter/features/home/presentation/widgets/code_viewer_sheet.dart';
import 'package:dosya_converter/features/share/presentation/screens/qr_share_screen.dart';

class UniversalConverterScreen extends StatefulWidget {
  final File? initialFile;

  const UniversalConverterScreen({super.key, this.initialFile});

  @override
  State<UniversalConverterScreen> createState() => _UniversalConverterScreenState();
}

class _UniversalConverterScreenState extends State<UniversalConverterScreen> {
  final UniversalConverterService _converter = const UniversalConverterService();
  final FileSelectorService _fileSelector = const FileSelectorService();
  final ZipArchiveService _zipService = const ZipArchiveService();

  File? _selectedFile;
  UniversalTargetFormat _targetFormat = UniversalTargetFormat.pdf;
  bool _isConverting = false;
  double _progress = 0.0;
  String _statusMessage = '';

  List<File> _convertedFiles = [];
  String? _previewText;

  bool get _isZip =>
      _selectedFile != null && p.extension(_selectedFile!.path).toLowerCase() == '.zip';

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _selectedFile = widget.initialFile;
      if (p.extension(widget.initialFile!.path).toLowerCase() == '.zip') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedFile != null) {
            _handleZipFlow(_selectedFile!);
          }
        });
      }
    }
  }

  Future<void> _pickFile() async {
    HapticFeedback.lightImpact();
    final result = await _fileSelector.pickUniversalFiles(allowMultiple: false);
    if (result.isCancelled || result.files.isEmpty) return;

    if (result.hasError) {
      if (!mounted) return;
      showFeedbackSnackBar(
        context,
        message: result.errorMessage!,
        icon: Icons.error_outline_rounded,
        backgroundColor: Colors.red.shade800,
      );
      return;
    }

    final picked = result.files.first;
    setState(() {
      _selectedFile = picked;
      _convertedFiles = [];
      _previewText = null;
    });

    if (p.extension(picked.path).toLowerCase() == '.zip') {
      await _handleZipFlow(picked);
    }
  }

  Future<void> _executeConversion() async {
    if (_selectedFile == null) return;
    if (_isZip) {
      await _handleZipFlow(_selectedFile!);
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isConverting = true;
      _progress = 0.05;
      _statusMessage = 'İşlem başlatılıyor...';
      _convertedFiles = [];
      _previewText = null;
    });

    try {
      final googleAuth = context.read<GoogleAuthService>();
      final msAuth = context.read<MicrosoftAuthService>();

      final result = await _converter.convert(
        file: _selectedFile!,
        target: _targetFormat,
        googleAuth: googleAuth,
        microsoftAuth: msAuth,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _progress = prog;
              _statusMessage = status;
            });
          }
        },
      );

      if (mounted) {
        context.read<HomeViewModel>().addResult(result);
      }

      String? previewContent;
      if (_targetFormat == UniversalTargetFormat.txt && await result.exists()) {
        try {
          final stream = result.openRead(0, 4096);
          final bytes = await stream.expand((b) => b).toList();
          final content = UniversalConverterService.decodeTextBytes(bytes);
          previewContent = content.length > 2500
              ? '${content.substring(0, 2500)}...\n[Devamı dosyada]'
              : content;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _convertedFiles = [result];
          _previewText = previewContent;
          _isConverting = false;
        });

        final extName = _targetFormat == UniversalTargetFormat.pdf ? 'PDF' : 'TXT';
        showFeedbackSnackBar(
          context,
          message: 'Dosya başarıyla $extName formatına dönüştürüldü!',
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF16A34A),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        showFeedbackSnackBar(
          context,
          message: 'Dönüştürme başarısız oldu: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: Colors.red.shade800,
        );
      }
    }
  }

  Future<void> _handleZipFlow(File zipFile) async {
    HapticFeedback.mediumImpact();

    setState(() {
      _isConverting = true;
      _progress = 0.05;
      _statusMessage = 'ZIP arşivi inceleniyor...';
      _convertedFiles = [];
      _previewText = null;
    });

    List<ZipEntryItem> entries;
    try {
      entries = await _zipService.inspectZip(zipFile);
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        showFeedbackSnackBar(
          context,
          message: 'ZIP arşivi okunamadı: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: Colors.red.shade800,
        );
      }
      return;
    }

    final convertible = entries.where((e) => e.isConvertible).toList();
    if (convertible.isEmpty) {
      if (mounted) {
        setState(() => _isConverting = false);
        showFeedbackSnackBar(
          context,
          message:
              'Arşiv içinde dönüştürülebilir belge bulunamadı (ses, video ve resimler dönüştürülmez).',
          icon: Icons.warning_amber_rounded,
          backgroundColor: Colors.amber.shade900,
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isConverting = false);

    final req = await ZipFilePickerSheet.show(
      context,
      zipFile: zipFile,
      entries: entries,
      isExtractOnly: false,
      defaultTarget: _targetFormat,
    );

    if (req == null || req.selectedPaths.isEmpty) return;

    final chosenTarget = req.targetFormat ?? _targetFormat;

    setState(() {
      _isConverting = true;
      _progress = 0.1;
      _statusMessage = 'Seçilen dosyalar arşivden çıkartılıyor...';
      _targetFormat = chosenTarget;
    });

    try {
      final extracted = await _zipService.extractSelectedFiles(
        zipFile: zipFile,
        selectedPaths: req.selectedPaths,
      );

      if (extracted.isEmpty) {
        if (mounted) {
          setState(() => _isConverting = false);
          showFeedbackSnackBar(
            context,
            message: 'Dosyalar arşivden çıkartılamadı.',
            icon: Icons.error_outline_rounded,
            backgroundColor: Colors.red.shade800,
          );
        }
        return;
      }

      if (!mounted) return;
      final googleAuth = context.read<GoogleAuthService>();
      final msAuth = context.read<MicrosoftAuthService>();
      final total = extracted.length;
      final outFiles = <File>[];

      for (var i = 0; i < total; i++) {
        final f = extracted[i];
        final name = p.basename(f.path);
        if (mounted) {
          setState(() {
            _progress = (i / total) + 0.05;
            _statusMessage = '$name dönüştürülüyor (${i + 1}/$total)...';
          });
        }

        final converted = await _converter.convert(
          file: f,
          target: chosenTarget,
          googleAuth: googleAuth,
          microsoftAuth: msAuth,
        );

        outFiles.add(converted);
        if (mounted) {
          context.read<HomeViewModel>().addResult(converted);
        }
      }

      String? preview;
      if (req.targetFormat == UniversalTargetFormat.txt && outFiles.isNotEmpty) {
        try {
          final firstFile = outFiles.first;
          if (await firstFile.exists()) {
            final stream = firstFile.openRead(0, 4096);
            final bytes = await stream.expand((b) => b).toList();
            final content = UniversalConverterService.decodeTextBytes(bytes);
            preview = content.length > 2500
                ? '${content.substring(0, 2500)}...\n[Devamı dosyada]'
                : content;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isConverting = false;
          _convertedFiles = outFiles;
          _previewText = preview;
        });

        final extName = req.targetFormat == UniversalTargetFormat.pdf ? 'PDF' : 'TXT';
        showFeedbackSnackBar(
          context,
          message: '${outFiles.length} dosya başarıyla $extName formatına dönüştürüldü!',
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF16A34A),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        showFeedbackSnackBar(
          context,
          message: 'ZIP dönüştürme hatası: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: Colors.red.shade800,
        );
      }
    }
  }

  Future<void> _previewFile(File file) async {
    HapticFeedback.lightImpact();
    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    if (UniversalConverterService.isTextOrCodeExtension(ext)) {
      CodeViewerSheet.show(context, file);
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Evrensel Dönüştürücü'),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ÜST BİLGİ KARTI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.transform_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Belgeler & Kodlar ➔ PDF / TXT',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Word, Excel, PowerPoint, Kodlar, Metin, CSV, Veri tabloları ve ZIP arşivleri.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outline,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. ADIM: DOSYA SEÇİM ALANI
            _buildSectionHeader('1. Kaynak Dosyayı Seçin', Icons.file_present_rounded),
            const SizedBox(height: 8),

            if (_selectedFile == null)
              _buildEmptyDropZone(colorScheme, isDark)
            else
              _buildSelectedFileCard(colorScheme),

            const SizedBox(height: 20),

            // 2. ADIM: HEDEF FORMAT SEÇİMİ (ZIP değilse gösterilir)
            if (!_isZip) ...[
              _buildSectionHeader('2. Hedef Çıktı Formatı', Icons.tune_rounded),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _TargetFormatTile(
                      title: 'PDF Belgesi',
                      ext: '.pdf',
                      description: 'A4 Sayfalı & Tipografik',
                      icon: Icons.picture_as_pdf_rounded,
                      accentColor: const Color(0xFFDC2626),
                      isSelected: _targetFormat == UniversalTargetFormat.pdf,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _targetFormat = UniversalTargetFormat.pdf);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TargetFormatTile(
                      title: 'Metin Dosyası',
                      ext: '.txt',
                      description: 'Temiz Metin / Veri',
                      icon: Icons.description_rounded,
                      accentColor: const Color(0xFFD97706),
                      isSelected: _targetFormat == UniversalTargetFormat.txt,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _targetFormat = UniversalTargetFormat.txt);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // DÖNÜŞTÜR BUTONU
            FilledButton.icon(
              onPressed: (_selectedFile == null || _isConverting) ? null : _executeConversion,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isConverting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _isZip ? Icons.folder_zip_rounded : Icons.check_circle_outline_rounded,
                      size: 20,
                    ),
              label: Text(
                _isConverting
                    ? 'İşleniyor (%${(_progress * 100).toInt()})...'
                    : (_isZip
                        ? 'ZIP İçeriğini İncele ve Dönüştür'
                        : (_targetFormat == UniversalTargetFormat.pdf
                            ? 'PDF Formatına Dönüştür'
                            : 'TXT Formatına Dönüştür')),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),

            if (_isConverting) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: colorScheme.outline),
              ),
            ],

            // 3. ADIM: DÖNÜŞTÜRÜLMÜŞ ÇIKTI KARTI
            if (_convertedFiles.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildSectionHeader(
                _convertedFiles.length > 1
                    ? '3. Hazır Çıktılar (${_convertedFiles.length} Dosya)'
                    : '3. Hazır Çıktı & Önizleme',
                Icons.task_alt_rounded,
              ),
              const SizedBox(height: 10),
              if (_convertedFiles.length == 1)
                _buildSingleResultCard(colorScheme, _convertedFiles.first)
              else
                _buildMultipleResultsCard(colorScheme),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: -0.2),
        ),
      ],
    );
  }

  Widget _buildEmptyDropZone(ColorScheme colorScheme, bool isDark) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.file_upload_outlined, color: colorScheme.primary, size: 26),
              ),
              const SizedBox(height: 14),
              const Text(
                'Dönüştürmek İstediğiniz Belgeyi Seçin',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Word, Excel, PowerPoint, Kodlar, Metin, CSV veya ZIP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                '(Ses, video ve resimler dönüştürülemez)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: colorScheme.outline.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Dosya Seç', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(ColorScheme colorScheme) {
    final name = p.basename(_selectedFile!.path);
    final ext = p.extension(_selectedFile!.path).replaceAll('.', '').toUpperCase();
    final sizeKB = (_selectedFile!.existsSync() ? _selectedFile!.lengthSync() / 1024 : 0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isZip ? Icons.folder_zip_rounded : Icons.insert_drive_file_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ext,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sizeKB KB',
                      style: TextStyle(fontSize: 11, color: colorScheme.outline),
                    ),
                    if (_isZip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ZIP Arşivi',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_isZip)
            FilledButton.tonal(
              onPressed: _isConverting ? null : () => _handleZipFlow(_selectedFile!),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: const Text('İçeriği Seç', style: TextStyle(fontSize: 11.5)),
            )
          else
            IconButton(
              tooltip: 'Farklı Dosya Seç',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: _pickFile,
            ),
        ],
      ),
    );
  }

  Widget _buildSingleResultCard(ColorScheme colorScheme, File file) {
    final fileName = p.basename(file.path);
    final isPdf = p.extension(file.path).toLowerCase() == '.pdf';
    final accent = isPdf ? const Color(0xFFDC2626) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPdf ? 'A4 PDF Belgesi' : 'Düz Metin (TXT)',
                      style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => _previewFile(file),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('Aç', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          if (_previewText != null) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _previewText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.4,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_previewText != null)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _previewText!));
                    HapticFeedback.lightImpact();
                    showFeedbackSnackBar(
                      context,
                      message: 'Metin panoya kopyalandı!',
                      icon: Icons.copy_rounded,
                      backgroundColor: const Color(0xFF16A34A),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Kopyala', style: TextStyle(fontSize: 12)),
                ),
              TextButton.icon(
                onPressed: () => Share.shareXFiles([XFile(file.path)]),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Paylaş', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QrShareScreen(file: file),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_rounded, size: 16),
                label: const Text('QR Gönder', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleResultsCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Dönüştürülen Dosyalar (${_convertedFiles.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Share.shareXFiles(_convertedFiles.map((f) => XFile(f.path)).toList());
                },
                icon: const Icon(Icons.share_rounded, size: 15),
                label: const Text('Tümünü Paylaş', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _convertedFiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final file = _convertedFiles[index];
              final name = p.basename(file.path);
              final isPdf = p.extension(file.path).toLowerCase() == '.pdf';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                      color: isPdf ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Aç',
                      onPressed: () => _previewFile(file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Paylaş',
                      onPressed: () => Share.shareXFiles([XFile(file.path)]),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TargetFormatTile extends StatelessWidget {
  final String title;
  final String ext;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _TargetFormatTile({
    required this.title,
    required this.ext,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected ? accentColor.withValues(alpha: 0.08) : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentColor : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: accentColor, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? accentColor : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ext,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 10, color: colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
