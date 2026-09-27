import 'dart:io';
import 'package:flutter/material.dart';
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
  DocumentFilterMode _selectedFilter = DocumentFilterMode.enhanceContrast;
  bool _isProcessing = false;
  int _currentPage = 0;
  int _totalPages = 0;
  String _statusText = 'Belgeler hazırlanıyor...';
  final PageController _pageController = PageController(viewportFraction: 0.75);
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
        filter: _selectedFilter,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
              if (current / total > 0.6) {
                _statusText = 'PDF sayfaları derleniyor ve sıkıştırılıyor...';
              } else {
                _statusText = 'Doküman filtreleri uygulanıyor ($current/$total)...';
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
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
                const SizedBox(height: 12),
                const Text(
                  'A4 Stüdyo PDF Hazır!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Ham Boyut', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(originalTotalBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                      Column(
                        children: [
                          const Text('Optimize PDF', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(newBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '%${savingsPercent.toStringAsFixed(1)} depolama tasarrufu sağlandı',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
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
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = _calculateTotalBytes();

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resim ➔ PDF Stüdyosu', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'Kamera ile Çek',
              icon: const Icon(Icons.add_a_photo_rounded),
              onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.camera),
            ),
            IconButton(
              tooltip: 'Galeriden Ekle',
              icon: const Icon(Icons.add_photo_alternate_rounded),
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
                const CircularProgressIndicator(color: Colors.indigo),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    value: _totalPages > 0 ? (_currentPage / _totalPages) : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _totalPages > 0
                      ? 'Sayfa işleniyor: $_currentPage / $_totalPages (%${((_currentPage / _totalPages) * 100).toInt()})'
                      : 'İşlem başlatılıyor...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        )
            : Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.collections_rounded, color: Colors.indigo, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_images.length} Resim Seçildi',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                  Text(
                    'Toplam: ${_formatBytes(totalBytes)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _filterChip('Sihirli Renk', DocumentFilterMode.enhanceContrast, Icons.auto_fix_high_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Gri Tonlama', DocumentFilterMode.blackAndWhite, Icons.filter_b_and_w_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Doğal Orijinal', DocumentFilterMode.none, Icons.photo_rounded),
                ],
              ),
            ),
            const Divider(height: 10),
            Expanded(
              child: _images.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Henüz resim seçilmedi.\nSağ üstten kamera veya galeriyle resim ekleyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.4),
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
                            height: MediaQuery.of(context).size.height * 0.48,
                            child: Card(
                              elevation: 4,
                              shadowColor: Colors.black.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(imgFile, fit: BoxFit.cover),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Sayfa ${index + 1} / ${_images.length}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _images.length,
                          (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _activeCarouselIndex == index ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _activeCarouselIndex == index ? Colors.indigo : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _images.isEmpty ? null : _convertToPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(
                    '${_images.length} Sayfayı PDF Yap (${_formatBytes(totalBytes)})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String title, DocumentFilterMode mode, IconData icon) {
    final isSelected = _selectedFilter == mode;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.indigo),
      label: Text(title),
      selected: isSelected,
      selectedColor: Colors.indigo,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = mode);
      },
    );
  }
}