import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as px;
import '../data/pdf_studio_service.dart';

class PdfStudioScreen extends StatefulWidget {
  const PdfStudioScreen({super.key});

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Birleştirme Durumu ---
  final List<File> _mergeFiles = [];
  bool _isMerging = false;

  // --- Ayıklama Durumu ---
  File? _splitFile;
  px.PdfDocument? _splitPdfDoc;
  int _splitTotalPages = 0;
  final Set<int> _selectedPages = {};
  bool _isSplitting = false;

  // Hızlı Ayıklama Önbelleği & Yükleme Kuyruğu
  final Map<int, Uint8List> _splitThumbs = {};
  final Set<int> _splitLoadingQueue = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _splitPdfDoc?.close();
    super.dispose();
  }

  // ================= BİRLEŞTİRME =================
  Future<void> _pickMergeFiles() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: false,
    );

    if (result != null && result.files.isNotEmpty) {
      for (final pf in result.files) {
        if (pf.path != null) {
          _mergeFiles.add(File(pf.path!));
        }
      }
      setState(() {});
    }
  }

  Future<void> _viewPdfFile(File file) async {
    HapticFeedback.lightImpact();
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya açılamadı: ${result.message}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleMerge() async {
    if (_mergeFiles.length < 2) return;

    HapticFeedback.mediumImpact();
    setState(() => _isMerging = true);

    try {
      final resultPdf = await PdfStudioService.mergePdfs(pdfFiles: _mergeFiles);
      if (mounted) Navigator.pop(context, resultPdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Birleştirme hatası: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  // ================= SAYFA AYIKLAMA =================
  Future<void> _pickSplitFile() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
    );

    if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await _splitPdfDoc?.close();
      _splitThumbs.clear();
      _splitLoadingQueue.clear();

      final doc = await px.PdfDocument.openFile(file.path);

      setState(() {
        _splitFile = file;
        _splitPdfDoc = doc;
        _splitTotalPages = doc.pagesCount;
        _selectedPages.clear();
      });
    }
  }

  Future<void> _renderThumbnailIfNeeded(int pageIndex) async {
    if (_splitThumbs.containsKey(pageIndex) || _splitLoadingQueue.contains(pageIndex)) {
      return;
    }
    if (_splitPdfDoc == null) return;

    _splitLoadingQueue.add(pageIndex);

    try {
      final page = await _splitPdfDoc!.getPage(pageIndex + 1);
      final double targetWidth = 140.0;
      final double targetHeight = (page.height / page.width) * targetWidth;

      final pageImg = await page.render(
        width: targetWidth,
        height: targetHeight,
        format: px.PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImg != null && mounted) {
        setState(() {
          _splitThumbs[pageIndex] = pageImg.bytes;
        });
      }
    } catch (e) {
      debugPrint('[SPLIT_THUMB_ERR] Sayfa $pageIndex: $e');
    } finally {
      _splitLoadingQueue.remove(pageIndex);
    }
  }

  void _showRangePickerDialog() {
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aralık Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: startCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Başlangıç', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: endCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bitiş', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final start = int.tryParse(startCtrl.text) ?? 1;
              final end = int.tryParse(endCtrl.text) ?? _splitTotalPages;
              if (start <= end && start >= 1 && end <= _splitTotalPages) {
                setState(() {
                  for (int i = start - 1; i <= end - 1; i++) {
                    _selectedPages.add(i);
                  }
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSplit() async {
    if (_splitFile == null || _selectedPages.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSplitting = true);

    try {
      final resultPdf = await PdfStudioService.splitPdfPages(
        sourcePdf: _splitFile!,
        selectedPageIndices: _selectedPages.toList(),
      );
      if (mounted) Navigator.pop(context, resultPdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayıklama hatası: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _isSplitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Stüdyosu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.merge_type_rounded), text: 'PDF Birleştir'),
            Tab(icon: Icon(Icons.call_split_rounded), text: 'Sayfa Ayıkla'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMergeTab(colorScheme),
          _buildSplitTab(colorScheme),
        ],
      ),
    );
  }

  // --- 1. TAB: BİRLEŞTİRME (Listeye Dokununca Doğrudan Açılır) ---
  Widget _buildMergeTab(ColorScheme colorScheme) {
    if (_isMerging) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF dosyaları birleştiriliyor...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Birleştirilecek Belgeler (${_mergeFiles.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              FilledButton.tonalIcon(
                onPressed: _pickMergeFiles,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('PDF Ekle', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mergeFiles.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_motion_rounded, size: 56, color: colorScheme.outlineVariant),
                const SizedBox(height: 12),
                const Text(
                  'En az 2 PDF ekleyin.\nBelgeye dokunarak içeriğini inceleyebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          )
              : ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _mergeFiles.length,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = _mergeFiles.removeAt(oldIdx);
                _mergeFiles.insert(newIdx, item);
              });
            },
            itemBuilder: (context, index) {
              final f = _mergeFiles[index];

              return Card(
                key: ValueKey(f.path),
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  onTap: () => _viewPdfFile(f),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                  ),
                  title: Text(
                    p.basename(f.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${index + 1}. Belge • ${(f.lengthSync() / 1024).toStringAsFixed(1)} KB • İncelemek için dokunun',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _mergeFiles.removeAt(index)),
                      ),
                      const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _mergeFiles.length >= 2 ? _handleMerge : null,
              icon: const Icon(Icons.merge_type_rounded),
              label: Text('${_mergeFiles.length} Dosyayı Birleştir', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. TAB: SAYFA AYIKLAMA ---
  Widget _buildSplitTab(ColorScheme colorScheme) {
    if (_isSplitting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Seçili sayfalar yeni PDF yapılıyor...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (_splitFile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view_rounded, size: 56, color: colorScheme.outlineVariant),
            const SizedBox(height: 14),
            const Text(
              'Sayfalarını ayıklamak istediğiniz\nPDF dosyasını seçin',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _pickSplitFile,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('PDF Dosyası Seç'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedPages.length}/$_splitTotalPages Sayfa Seçili',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: _showRangePickerDialog,
                child: const Text('Aralık Seç (1-X)', style: TextStyle(fontSize: 11)),
              ),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () {
                  setState(() {
                    if (_selectedPages.length == _splitTotalPages) {
                      _selectedPages.clear();
                    } else {
                      _selectedPages.addAll(List.generate(_splitTotalPages, (i) => i));
                    }
                  });
                },
                child: Text(_selectedPages.length == _splitTotalPages ? 'Temizle' : 'Tümü', style: const TextStyle(fontSize: 11)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Farklı PDF Seç',
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                onPressed: _pickSplitFile,
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: _splitTotalPages,
            itemBuilder: (context, index) {
              final isSelected = _selectedPages.contains(index);
              final thumbBytes = _splitThumbs[index];

              if (thumbBytes == null) {
                _renderThumbnailIfNeeded(index);
              }

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selectedPages.remove(index);
                    } else {
                      _selectedPages.add(index);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.35),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumbBytes != null)
                        Image.memory(thumbBytes, fit: BoxFit.cover, gaplessPlayback: true)
                      else
                        Container(
                          color: Colors.grey.shade100,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: isSelected ? colorScheme.primary : Colors.black26,
                          child: Icon(
                            isSelected ? Icons.check_rounded : Icons.circle_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _selectedPages.isNotEmpty ? _handleSplit : null,
              icon: const Icon(Icons.call_split_rounded),
              label: Text('${_selectedPages.length} Sayfayı Yeni PDF Yap', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}