import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/files/temp_file_manager.dart';
import '../../data/doc_scanner_service.dart';

class DocScannerScreen extends StatefulWidget {
  final List<File> initialImages;

  const DocScannerScreen({super.key, required this.initialImages});

  @override
  State<DocScannerScreen> createState() => _DocScannerScreenState();
}

class _DocScannerScreenState extends State<DocScannerScreen> {
  late List<File> _images;
  late List<int> _rotations; // Her sayfanın dönüş açısı (0, 90, 180, 270)
  DocumentFilterMode _selectedFilter = DocumentFilterMode.magicColor;

  bool _isProcessing = false;
  int _currentPage = 0;
  int _totalPages = 0;
  String _statusText = 'Belgeler hazırlanıyor...';

  final PageController _pageController = PageController(viewportFraction: 0.82);
  int _activeCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
    _rotations = List.generate(_images.length, (_) => 0);
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
    HapticFeedback.lightImpact();
    final picker = ImagePicker();

    if (source == ImageSource.camera) {
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (photo != null) {
        setState(() {
          _images.add(File(photo.path));
          _rotations.add(0);
        });
      }
    } else {
      final pickedFiles = await picker.pickMultiImage(imageQuality: 95);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _images.addAll(pickedFiles.map((x) => File(x.path)));
          _rotations.addAll(List.generate(pickedFiles.length, (_) => 0));
        });
      }
    }
  }

  void _rotateCurrentPage() {
    if (_images.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _rotations[_activeCarouselIndex] = (_rotations[_activeCarouselIndex] + 90) % 360;
    });
  }

  void _reorderPage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _images.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final file = _images.removeAt(oldIndex);
      final rot = _rotations.removeAt(oldIndex);
      _images.insert(newIndex, file);
      _rotations.insert(newIndex, rot);
      _activeCarouselIndex = newIndex;
      _pageController.jumpToPage(newIndex);
    });
  }

  Future<void> _convertToPdf() async {
    if (_images.isEmpty) return;

    final originalTotalBytes = _calculateTotalBytes();

    setState(() {
      _isProcessing = true;
      _currentPage = 0;
      _totalPages = _images.length;
      _statusText = 'Belgeler A4 standardına uyarlanıyor...';
    });

    try {
      final pdfFile = await DocScannerService.createScannedPdf(
        imageFiles: _images,
        rotations: _rotations,
        filter: _selectedFilter,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
              if (current / total > 0.6) {
                _statusText = 'A4 sayfaları derleniyor ve sıkıştırılıyor...';
              } else {
                _statusText = 'Belge filtreleri uygulanıyor ($current/$total)...';
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
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 52),
                const SizedBox(height: 12),
                const Text(
                  'Taranmış PDF Belgeniz Hazır!',
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
                          const Text('Ham Görseller', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(originalTotalBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '%${savingsPercent.toStringAsFixed(1)} boyut tasarrufu sağlandı',
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
          title: const Text('Belge Tarama Stüdyosu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            IconButton(
              tooltip: 'Kamerayla Sayfa Çek',
              icon: const Icon(Icons.add_a_photo_rounded),
              onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.camera),
            ),
            IconButton(
              tooltip: 'Galeriden Sayfa Ekle',
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
            // Durum ve Sayfa Bilgisi
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.document_scanner_rounded, color: Colors.indigo, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_images.length} Sayfa Hazır',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
                      ),
                    ],
                  ),
                  Text(
                    'Boyut: ${_formatBytes(totalBytes)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // CamScanner Filtre Çubuğu
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _filterChip('Sihirli Renk', DocumentFilterMode.magicColor, Icons.auto_fix_high_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Temiz Metin (S&B)', DocumentFilterMode.blackAndWhite, Icons.filter_b_and_w_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Gri Ton', DocumentFilterMode.grayscale, Icons.gradient_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Doğal', DocumentFilterMode.none, Icons.photo_rounded),
                ],
              ),
            ),
            const Divider(height: 10),

            // Önizleme ve Sayfa Düzenleme Alanı
            Expanded(
              child: _images.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Henüz sayfa taranmadı.\nSağ üstteki butonlardan kamera veya galeri seçin.',
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
                        final rot = _rotations[index];

                        return Center(
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.46,
                            child: Card(
                              elevation: 4,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  RotatedBox(
                                    quarterTurns: rot ~/ 90,
                                    child: Image.file(imgFile, fit: BoxFit.contain),
                                  ),
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                    top: 10,
                                    right: 10,
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _images.removeAt(index);
                                            _rotations.removeAt(index);
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

                  // Sayfa Altı Hızlı Araçlar (Döndürme, Öne/Arkaya Taşıma)
                  if (_images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Önceki Sayfayla Değiştir',
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            onPressed: _activeCarouselIndex > 0
                                ? () => _reorderPage(_activeCarouselIndex, _activeCarouselIndex - 1)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          ActionChip(
                            avatar: const Icon(Icons.rotate_right_rounded, size: 18, color: Colors.indigo),
                            label: const Text('90° Döndür', style: TextStyle(fontSize: 12)),
                            onPressed: _rotateCurrentPage,
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Sonraki Sayfayla Değiştir',
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            onPressed: _activeCarouselIndex < _images.length - 1
                                ? () => _reorderPage(_activeCarouselIndex, _activeCarouselIndex + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 4),
                ],
              ),
            ),

            // Alt PDF Oluştur Butonu
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
                height: 50,
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
                    '${_images.length} Sayfayı Belge Olarak Kaydet',
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