import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/universal_converter_service.dart';
import '../../data/zip_archive_service.dart';

class ZipConversionRequest {
  final List<String> selectedPaths;
  final UniversalTargetFormat? targetFormat;
  final bool isExtractOnly;

  const ZipConversionRequest({
    required this.selectedPaths,
    this.targetFormat,
    this.isExtractOnly = false,
  });
}

/// ZIP arşivindeki belgeleri listeleyen, ayıklama veya dönüştürme seçimini sağlayan panel.
class ZipFilePickerSheet extends StatefulWidget {
  final File zipFile;
  final List<ZipEntryItem> entries;
  final bool isExtractOnly;
  final UniversalTargetFormat defaultTarget;

  const ZipFilePickerSheet({
    super.key,
    required this.zipFile,
    required this.entries,
    this.isExtractOnly = false,
    this.defaultTarget = UniversalTargetFormat.pdf,
  });

  static Future<ZipConversionRequest?> show(
    BuildContext context, {
    required File zipFile,
    required List<ZipEntryItem> entries,
    bool isExtractOnly = false,
    UniversalTargetFormat defaultTarget = UniversalTargetFormat.pdf,
  }) {
    return showModalBottomSheet<ZipConversionRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ZipFilePickerSheet(
        zipFile: zipFile,
        entries: entries,
        isExtractOnly: isExtractOnly,
        defaultTarget: defaultTarget,
      ),
    );
  }

  @override
  State<ZipFilePickerSheet> createState() => _ZipFilePickerSheetState();
}

class _ZipFilePickerSheetState extends State<ZipFilePickerSheet> {
  final Set<String> _selectedPaths = {};
  late UniversalTargetFormat _targetFormat;

  List<ZipEntryItem> get _displayEntries =>
      widget.isExtractOnly ? widget.entries : widget.entries.where((e) => e.isConvertible).toList();

  @override
  void initState() {
    super.initState();
    _targetFormat = widget.defaultTarget;
    for (final entry in _displayEntries) {
      _selectedPaths.add(entry.path);
    }
  }

  void _toggleSelectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPaths.length == _displayEntries.length) {
        _selectedPaths.clear();
      } else {
        _selectedPaths.clear();
        for (final entry in _displayEntries) {
          _selectedPaths.add(entry.path);
        }
      }
    });
  }

  void _toggleItem(String path) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final zipName = p.basename(widget.zipFile.path);
    final totalCount = _displayEntries.length;
    final selectedCount = _selectedPaths.length;
    final allSelected = selectedCount == totalCount && totalCount > 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A20) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Tutamak (Drag Handle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Başlık Alanı
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (widget.isExtractOnly ? const Color(0xFF4E8772) : const Color(0xFF3B5EDB))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.isExtractOnly ? Icons.unarchive_rounded : Icons.folder_zip_rounded,
                      color: widget.isExtractOnly ? const Color(0xFF4E8772) : const Color(0xFF3B5EDB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isExtractOnly ? 'ZIP Arşivini Ayıkla' : zipName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isExtractOnly
                              ? '$totalCount dosya bulundu (Orijinal formatında çıkarılır)'
                              : '$totalCount çevrilebilir belge tespit edildi',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
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

            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),

            // Tümünü Seç / Kaldır
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.isExtractOnly
                        ? 'Çıkarılacak Dosyaları Seçin ($selectedCount / $totalCount)'
                        : 'Dönüştürülecek Dosyaları Seçin ($selectedCount / $totalCount)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: totalCount == 0 ? null : _toggleSelectAll,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      allSelected ? 'Seçimi Kaldır' : 'Tümünü Seç',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dosya Listesi
            if (totalCount == 0)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    widget.isExtractOnly
                        ? 'Bu ZIP arşivi boş.'
                        : 'Bu ZIP arşivinde dönüştürülebilir belge (Word, Excel, PDF, Kod, Metin vb.) bulunamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: colorScheme.outline),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _displayEntries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = _displayEntries[index];
                    final isChecked = _selectedPaths.contains(item.path);

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleItem(item.path),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChecked
                                ? colorScheme.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (_) => _toggleItem(item.path),
                              activeColor: colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            _buildFileIcon(item.extension),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    item.formattedSize,
                                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),

            // Alt Eylem Butonları
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.isExtractOnly) ...[
                    Row(
                      children: [
                        const Text(
                          'Hedef Format:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('PDF Yap (.pdf)', style: TextStyle(fontSize: 11.5)),
                          selected: _targetFormat == UniversalTargetFormat.pdf,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _targetFormat = UniversalTargetFormat.pdf);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('TXT Yap (.txt)', style: TextStyle(fontSize: 11.5)),
                          selected: _targetFormat == UniversalTargetFormat.txt,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _targetFormat = UniversalTargetFormat.txt);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  FilledButton.icon(
                    onPressed: selectedCount == 0
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(
                              context,
                              ZipConversionRequest(
                                selectedPaths: _selectedPaths.toList(),
                                targetFormat: widget.isExtractOnly ? null : _targetFormat,
                                isExtractOnly: widget.isExtractOnly,
                              ),
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.isExtractOnly ? const Color(0xFF4E8772) : colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      widget.isExtractOnly ? Icons.unarchive_rounded : Icons.transform_rounded,
                      size: 19,
                    ),
                    label: Text(
                      widget.isExtractOnly
                          ? 'Seçilen $selectedCount Dosyayı Arşivden Çıkar'
                          : 'Seçilen $selectedCount Dosyayı Dönüştür',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(String ext) {
    Color color = Colors.grey.shade600;
    IconData icon = Icons.insert_drive_file_rounded;

    switch (ext) {
      case 'pdf':
        color = const Color(0xFFC46B6B);
        icon = Icons.picture_as_pdf_rounded;
        break;
      case 'docx':
      case 'doc':
        color = const Color(0xFF4A7C9F);
        icon = Icons.article_rounded;
        break;
      case 'xlsx':
      case 'xls':
        color = const Color(0xFF4E8772);
        icon = Icons.table_chart_rounded;
        break;
      case 'pptx':
      case 'ppt':
        color = const Color(0xFFC88A58);
        icon = Icons.slideshow_rounded;
        break;
      case 'txt':
      case 'log':
      case 'ini':
      case 'env':
        color = const Color(0xFF6B7280);
        icon = Icons.description_rounded;
        break;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'csv':
      case 'tsv':
        color = const Color(0xFFC88A3A);
        icon = Icons.data_object_rounded;
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
        color = const Color(0xFF8E7CB0);
        icon = Icons.image_rounded;
        break;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'ogg':
        color = const Color(0xFFC88A3A);
        icon = Icons.audio_file_rounded;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        color = const Color(0xFF5A7BA6);
        icon = Icons.video_file_rounded;
        break;
      default:
        color = const Color(0xFF5E6AD2);
        icon = Icons.code_rounded;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}
