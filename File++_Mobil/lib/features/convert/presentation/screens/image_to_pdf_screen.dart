import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/image_to_pdf_converter.dart';

class ImageToPdfScreen extends StatefulWidget {
  final List<File>? initialImages;

  const ImageToPdfScreen({super.key, this.initialImages});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  late List<File> _images;
  int _imagesPerPage = 1; // 1, 2, 4, 6, 9
  bool _isProcessing = false;
  int _currentPage = 0;
  int _totalPages = 0;
  String _statusText = 'Belgeler hazırlanıyor...';
  final PageController _pageController = PageController(viewportFraction: 0.78);
  int _activeCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages ?? []);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _calculateTotalBytes() {
    int total = 0;
    for (final f in _images) {
      if (f.existsSync()) {
        total += f.lengthSync();
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get _calculatedPdfPages {
    if (_images.isEmpty) return 0;
    return (_images.length / _imagesPerPage).ceil();
  }

  Future<void> _addMoreImages({required ImageSource source}) async {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _images.add(File(photo.path)));
      }
    } else {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _images.addAll(pickedFiles.map((x) => File(x.path)));
        });
      }
    }
  }

  Future<void> _convertToPdf() async {
    if (_images.isEmpty) return;
    HapticFeedback.mediumImpact();

    final originalTotalBytes = _calculateTotalBytes();

    setState(() {
      _isProcessing = true;
      _currentPage = 0;
      _totalPages = _images.length;
      _statusText = 'Görseller A4 standardına ölçekleniyor...';
    });

    try {
      final pdfFile = await ImageToPdfConverter.createScannedPdf(
        imageFiles: _images,
        imagesPerPage: _imagesPerPage,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
              if (current / total > 0.6) {
                _statusText = 'A4 sayfaları matris düzenine yerleştiriliyor...';
              } else {
                _statusText = 'Görseller işleniyor ($current/$total)...';
              }
            });
          }
        },
      );

      if (!mounted) return;

      final newBytes = pdfFile.lengthSync();
      final savingsPercent = originalTotalBytes > 0
          ? (((originalTotalBytes - newBytes) / originalTotalBytes) * 100).clamp(0.0, 99.9)
          : 0.0;

      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF4E8772), size: 54),
                const SizedBox(height: 12),
                const Text(
                  'A4 PDF Belgesi Hazır!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_calculatedPdfPages sayfa • Sayfa başı $_imagesPerPage görsel matrisi',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Ham Boyut', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(originalTotalBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC46B6B)),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                      Column(
                        children: [
                          const Text('Optimize PDF', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(newBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4E8772)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '%${savingsPercent.toStringAsFixed(1)} depolama tasarrufu sağlandı',
                  style: const TextStyle(color: Color(0xFF4E8772), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, pdfFile);
                    },
                    child: const Text('Tamamla ve Listeye Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: const Color(0xFFC46B6B)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final totalBytes = _calculateTotalBytes();

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Görselleri PDF Yap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Kamera ile Çek',
              icon: const Icon(Icons.add_a_photo_rounded, size: 21),
              onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.camera),
            ),
            IconButton(
              tooltip: 'Galeriden Ekle',
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 21),
              onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.gallery),
            ),
          ],
        ),
        body: _isProcessing
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(
                          value: _totalPages > 0 ? (_currentPage / _totalPages) : null,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _totalPages > 0
                            ? 'Görsel işleniyor: $_currentPage / $_totalPages'
                            : 'İşlem başlatılıyor...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.outline, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Seçili Görsel ve Boyut Bilgisi
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.collections_rounded, color: colorScheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${_images.length} Resim Seçildi',
                              style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.primary, fontSize: 13),
                            ),
                          ],
                        ),
                        Text(
                          'Boyut: ${_formatBytes(totalBytes)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),

                  // MATRİS SEÇİCİ: Bir Sayfaya Kaç Resim?
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141824) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_view_rounded, size: 15, color: colorScheme.outline),
                            const SizedBox(width: 6),
                            const Text(
                              'Sayfa Başına Matris:',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              _images.isNotEmpty ? 'Toplam $_calculatedPdfPages Sayfa' : '',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _matrixChip(1, '1x1 (Tam)', Icons.crop_portrait_rounded),
                              const SizedBox(width: 6),
                              _matrixChip(2, '1x2 (İkili)', Icons.view_agenda_rounded),
                              const SizedBox(width: 6),
                              _matrixChip(4, '2x2 (Dörtlü)', Icons.grid_view_rounded),
                              const SizedBox(width: 6),
                              _matrixChip(6, '2x3 (Altılı)', Icons.table_rows_rounded),
                              const SizedBox(width: 6),
                              _matrixChip(9, '3x3 (Dokuzlu)', Icons.grid_on_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Görsel Galerisi / Carousel
                  Expanded(
                    child: _images.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 56, color: colorScheme.outline.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'Henüz görsel eklenmedi.\nÜst menüden kamera veya galeriyi kullanın.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colorScheme.outline, height: 1.4, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _images.length,
                                  onPageChanged: (idx) => setState(() => _activeCarouselIndex = idx),
                                  itemBuilder: (context, index) {
                                    final imgFile = _images[index];
                                    return Center(
                                      child: SizedBox(
                                        height: MediaQuery.of(context).size.height * 0.44,
                                        child: Card(
                                          elevation: 2,
                                          shadowColor: Colors.black.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                          clipBehavior: Clip.antiAlias,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.file(imgFile, fit: BoxFit.cover),
                                              Positioned(
                                                top: 10,
                                                left: 10,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${index + 1} / ${_images.length}',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: CircleAvatar(
                                                  radius: 17,
                                                  backgroundColor: Colors.black.withValues(alpha: 0.65),
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                                    onPressed: () {
                                                      setState(() {
                                                        _images.removeAt(index);
                                                        if (_activeCarouselIndex >= _images.length && _images.isNotEmpty) {
                                                          _activeCarouselIndex = _images.length - 1;
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _images.length.clamp(0, 15),
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                    width: _activeCarouselIndex == index ? 16 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: _activeCarouselIndex == index ? colorScheme.primary : colorScheme.outlineVariant,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                  ),

                  // Alt Buton
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _images.isEmpty ? null : _convertToPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                        label: Text(
                          _images.isEmpty
                              ? 'Resim Seçin'
                              : '${_images.length} Resmi PDF Yap ($_calculatedPdfPages Sayfa • ${_imagesPerPage}x)',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _matrixChip(int perPage, String label, IconData icon) {
    final isSelected = _imagesPerPage == perPage;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerLow,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11.5,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() => _imagesPerPage = perPage);
        }
      },
    );
  }
}