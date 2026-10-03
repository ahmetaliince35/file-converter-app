import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/feedback_snack_bar.dart';
import '../../../convert/data/universal_converter_service.dart';
import '../view_models/home_view_model.dart';

/// Tüm programlama dili kaynak kodlarını ve yapılandırılmış metin dosyalarını
/// harici uygulamaya ihtiyaç duymadan uygulama içinde satır numaraları,
/// monospaced tipografi, kopyalama, paylaşma ve PDF'e dönüştürme araçlarıyla açan gelişmiş görüntüleyici.
class CodeViewerSheet extends StatefulWidget {
  final File file;

  const CodeViewerSheet({super.key, required this.file});

  static Future<void> show(BuildContext context, File file) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CodeViewerSheet(file: file),
    );
  }

  @override
  State<CodeViewerSheet> createState() => _CodeViewerSheetState();
}

class _CodeViewerSheetState extends State<CodeViewerSheet> {
  String? _content;
  List<String> _lines = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;
  bool _isConvertingToPdf = false;
  bool _isTruncated = false;

  static const int _maxDisplayLines = 3000;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  Future<void> _loadFileContent() async {
    try {
      if (!await widget.file.exists()) {
        setState(() {
          _errorMessage = 'Dosya bulunamadı veya silinmiş.';
          _isLoading = false;
        });
        return;
      }

      _fileSizeBytes = widget.file.lengthSync();

      // Devasa dosyalarda bellek patlamasını önle (Maks. ilk 5 MB oku)
      String text;
      if (_fileSizeBytes > 5 * 1024 * 1024) {
        final stream = widget.file.openRead(0, 3 * 1024 * 1024);
        final bytes = await stream.expand((b) => b).toList();
        text = UniversalConverterService.decodeTextBytes(bytes);
        _isTruncated = true;
      } else {
        final bytes = await widget.file.readAsBytes();
        text = UniversalConverterService.decodeTextBytes(bytes);
      }

      final rawLines = text.split('\n');
      final linesToDisplay = rawLines.length > _maxDisplayLines
          ? rawLines.sublist(0, _maxDisplayLines)
          : rawLines;

      if (rawLines.length > _maxDisplayLines) {
        _isTruncated = true;
      }

      if (mounted) {
        setState(() {
          _content = linesToDisplay.join('\n');
          _lines = linesToDisplay;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Dosya okunurken bir hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  String get _formattedSize {
    if (_fileSizeBytes < 1024) return '$_fileSizeBytes B';
    if (_fileSizeBytes < 1024 * 1024) {
      return '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _extension {
    return p.extension(widget.file.path).replaceFirst('.', '').toUpperCase();
  }

  Future<void> _copyAll() async {
    if (_content == null || _content!.isEmpty) return;
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: _content!));
    if (mounted) {
      showFeedbackSnackBar(
        context,
        message: 'Kod içeriği panoya kopyalandı!',
        icon: Icons.copy_all_rounded,
        backgroundColor: const Color(0xFF16A34A),
      );
    }
  }

  Future<void> _shareFile() async {
    HapticFeedback.lightImpact();
    await Share.shareXFiles([XFile(widget.file.path)]);
  }

  Future<void> _openExternal() async {
    HapticFeedback.lightImpact();
    final result = await OpenFilex.open(widget.file.path);
    if (result.type != ResultType.done && mounted) {
      showFeedbackSnackBar(
        context,
        message: 'Harici uygulama bulunamadı: ${result.message}',
        icon: Icons.info_outline_rounded,
        backgroundColor: const Color(0xFFD97706),
      );
    }
  }

  Future<void> _convertToPdf() async {
    setState(() => _isConvertingToPdf = true);
    HapticFeedback.mediumImpact();

    try {
      const converter = UniversalConverterService();
      final pdfFile = await converter.convert(
        file: widget.file,
        target: UniversalTargetFormat.pdf,
      );

      if (mounted) {
        context.read<HomeViewModel>().addResult(pdfFile);
        Navigator.pop(context); // Viewer modalını kapat
        showFeedbackSnackBar(
          context,
          message: '${widget.file.path.split(Platform.pathSeparator).last} A4 PDF belgesine dönüştürüldü!',
          icon: Icons.picture_as_pdf_rounded,
          backgroundColor: const Color(0xFF16A34A),
        );
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context,
          message: 'PDF dönüştürme hatası: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFDC2626),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConvertingToPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fileName = p.basename(widget.file.path);

    // Koyu mod için sakin kömür/arduvaz editör renkleri (parlama veya zıtlık içermez)
    final editorBg = isDark ? const Color(0xFF141519) : const Color(0xFFF9F9FB);
    final gutterBg = isDark ? const Color(0xFF181A20) : const Color(0xFFEEEEF2);
    final gutterTextColor = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final codeTextColor = isDark ? const Color(0xFFE4E4E7) : const Color(0xFF1E2024);
    const accentIndigo = Color(0xFF6366F1);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1D22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Tutamaç (Drag handle)
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // BAŞLIK BÖLÜMÜ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code_rounded, color: accentIndigo, size: 20),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentIndigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _extension.isEmpty ? 'KOD' : _extension,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentIndigo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_formattedSize • ${_lines.length} Satır',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),

          // HIZLI AKSİYON ÇUBUĞU
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Kopyala',
                  onTap: _copyAll,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: _isConvertingToPdf ? 'PDF Yapılıyor...' : 'A4 PDF Yap',
                  color: const Color(0xFFDC2626),
                  isLoading: _isConvertingToPdf,
                  onTap: _isConvertingToPdf ? null : _convertToPdf,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Paylaş',
                  onTap: _shareFile,
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Harici Aç', style: TextStyle(fontSize: 11.5)),
                  onPressed: _openExternal,
                ),
              ],
            ),
          ),

          if (_isTruncated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              color: const Color(0xFFD97706).withValues(alpha: 0.1),
              child: const Text(
                'Performans güvenliği için ilk 3.000 satır görüntülenmektedir. Tamamını PDF Yap veya Harici Aç ile kullanabilirsiniz.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
              ),
            ),

          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.25)),

          // KOD METİN ALANI (Satır Numaralı ve Kaydırılabilir)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: editorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF282A34) : const Color(0xFFE2E4EB),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Sol: Satır Numaraları
                            Container(
                              width: 44,
                              color: gutterBg,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  children: [
                                    for (int idx = 0; idx < _lines.length; idx++)
                                      SizedBox(
                                        height: 20,
                                        child: Center(
                                          child: Text(
                                            '${idx + 1}',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: gutterTextColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Ayırıcı çizgi
                            Container(
                              width: 1,
                              color: isDark ? const Color(0xFF282A34) : const Color(0xFFE2E4EB),
                            ),

                            // 2. Sağ: Kod Gövdesi
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: SelectableText(
                                    _content ?? '',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      height: 1.62,
                                      color: codeTextColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnColor = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 14, color: btnColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: btnColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
