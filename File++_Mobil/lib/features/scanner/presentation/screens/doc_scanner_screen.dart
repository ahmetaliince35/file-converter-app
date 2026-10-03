import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 92);
      if (photo != null) {
        setState(() {
          _images.add(File(photo.path));
          _rotations.add(0);
        });
      }
    } else {
      final pickedFiles = await picker.pickMultiImage(imageQuality: 92);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final colorScheme = Theme.of(ctx).colorScheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
                const SizedBox(height: 10),
                const Text(
                  'Taranmış PDF Belgeniz Hazır',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Ham Görseller', style: TextStyle(fontSize: 11, color: colorScheme.outline)),
                          const SizedBox(height: 3),
                          Text(
                            _formatBytes(originalTotalBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward_rounded, color: colorScheme.outline, size: 18),
                      Column(
                        children: [
                          Text('Optimize PDF', style: TextStyle(fontSize: 11, color: colorScheme.outline)),
                          const SizedBox(height: 3),
                          Text(
                            _formatBytes(newBytes),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '%${savingsPercent.toStringAsFixed(1)} boyut tasarrufu sağlandı',
                  style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, pdfFile);
                    },
                    child: const Text('Tamamla ve Listeye Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: const Color(0xFFDC2626)),
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
    final totalBytes = _calculateTotalBytes();

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Belge Tarama Stüdyosu'),
          actions: [
            IconButton(
              tooltip: 'Kamerayla Sayfa Çek',
              icon: const Icon(Icons.add_a_photo_rounded, size: 20),
              onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.camera),
            ),
            IconButton(
              tooltip: 'Galeriden Sayfa Ekle',
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
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
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    value: _totalPages > 0 ? (_currentPage / _totalPages) : null,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _totalPages > 0
                      ? 'Sayfa işleniyor: $_currentPage / $_totalPages (%${((_currentPage / _totalPages) * 100).toInt()})'
                      : 'İşlem başlatılıyor...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.outline, fontSize: 12),
                ),
              ],
            ),
          ),
        )
            : Column(
          children: [
            // Durum ve Sayfa Bilgisi
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.document_scanner_rounded, color: colorScheme.primary, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        '${_images.length} Sayfa Hazır',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12.5),
                      ),
                    ],
                  ),
                  Text(
                    'Toplam: ${_formatBytes(totalBytes)}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: colorScheme.outline),
                  ),
                ],
              ),
            ),

            // CamScanner Filtre Çubuğu
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  _filterChip('Sihirli Renk', DocumentFilterMode.magicColor, Icons.auto_fix_high_rounded, colorScheme),
                  const SizedBox(width: 8),
                  _filterChip('Temiz Metin (S&B)', DocumentFilterMode.blackAndWhite, Icons.filter_b_and_w_rounded, colorScheme),
                  const SizedBox(width: 8),
                  _filterChip('Gri Ton', DocumentFilterMode.grayscale, Icons.gradient_rounded, colorScheme),
                  const SizedBox(width: 8),
                  _filterChip('Doğal', DocumentFilterMode.none, Icons.photo_rounded, colorScheme),
                ],
              ),
            ),
            Divider(height: 8, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),

            // Önizleme ve Sayfa Düzenleme Alanı
            Expanded(
              child: _images.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner_outlined, size: 54, color: colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz sayfa taranmadı.\nSağ üstteki butonlardan kamera veya galeri seçin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.outline, height: 1.4, fontSize: 12.5),
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
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                              ),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${index + 1} / ${_images.length}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.black54,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 16),
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

                  // Sayfa Altı Hızlı Araçlar
                  if (_images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Önceki Sayfayla Değiştir',
                            icon: const Icon(Icons.arrow_back_rounded, size: 17),
                            onPressed: _activeCarouselIndex > 0
                                ? () => _reorderPage(_activeCarouselIndex, _activeCarouselIndex - 1)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          ActionChip(
                            avatar: Icon(Icons.rotate_right_rounded, size: 16, color: colorScheme.primary),
                            label: const Text('90° Döndür', style: TextStyle(fontSize: 11.5)),
                            onPressed: _rotateCurrentPage,
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Sonraki Sayfayla Değiştir',
                            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
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

            // Alt PDF Oluştur Butonu (Temaya tam uyumlu)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _images.isEmpty ? null : _convertToPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    '${_images.length} Sayfayı Belge Olarak Kaydet',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String title, DocumentFilterMode mode, IconData icon, ColorScheme colorScheme) {
    final isSelected = _selectedFilter == mode;
    return ChoiceChip(
      avatar: Icon(icon, size: 15, color: isSelected ? Colors.white : colorScheme.onSurfaceVariant),
      label: Text(title),
      selected: isSelected,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = mode);
      },
    );
  }
}