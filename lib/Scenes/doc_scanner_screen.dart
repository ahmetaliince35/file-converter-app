import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../services/doc_scanner_service.dart';

class DocScannerScreen extends StatefulWidget {
  final List<File> initialImages;

  const DocScannerScreen({super.key, required this.initialImages});

  @override
  State<DocScannerScreen> createState() => _DocScannerScreenState();
}

class _DocScannerScreenState extends State<DocScannerScreen> {
  late List<File> _images;
  DocumentFilterMode _selectedFilter = DocumentFilterMode.enhanceContrast;
  bool _isProcessing = false;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
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
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir fotoğraf ekleyin.')),
      );
      return;
    }

    final originalTotalBytes = _calculateTotalBytes();

    setState(() {
      _isProcessing = true;
      _currentPage = 0;
      _totalPages = _images.length;
    });

    try {
      final pdfFile = await DocScannerService.createScannedPdf(
        imageFiles: _images,
        filter: _selectedFilter,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
            });
          }
        },
      );

      if (!mounted) return;

      final newBytes = pdfFile.lengthSync();
      final savingsPercent = originalTotalBytes > 0
          ? (((originalTotalBytes - newBytes) / originalTotalBytes) * 100).clamp(0.0, 99.9)
          : 0.0;

      // İşlem bitince boyut tasarrufunu gösteren şık modal
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
                  'A4 PDF Başarıyla Optimize Edildi!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
                          const Text('Fotoğraf Toplamı', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = _calculateTotalBytes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Belge Tara (A4 PDF)'),
        actions: [
          IconButton(
            tooltip: 'Kamera ile Çek',
            icon: const Icon(Icons.add_a_photo_rounded),
            onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.camera),
          ),
          IconButton(
            tooltip: 'Galeriden Seç',
            icon: const Icon(Icons.add_photo_alternate_rounded),
            onPressed: _isProcessing ? null : () => _addMoreImages(source: ImageSource.gallery),
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Sayfa işleniyor: $_currentPage / $_totalPages',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Çözünürlük A4 standardına indiriliyor & sıkıştırılıyor...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // 1. CANLI BOYUT BİLGİ KARTI
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    const Icon(Icons.analytics_outlined, color: Colors.indigo, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${_images.length} Sayfa',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Ham Görsel Boyutu: ',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        _formatBytes(totalBytes),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. FİLTRE SEÇİM ÇUBUĞU
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _filterChip('Canlı Belge', DocumentFilterMode.enhanceContrast, Icons.auto_fix_high_rounded),
                _filterChip('Fotokopi (S/B)', DocumentFilterMode.blackAndWhite, Icons.filter_b_and_w_rounded),
                _filterChip('Orijinal', DocumentFilterMode.none, Icons.photo_rounded),
              ],
            ),
          ),

          const Divider(height: 12),

          // 3. SAYFALAR LİSTESİ (HER BİRİNİN DOSYA ADI VE BOYUTU)
          Expanded(
            child: _images.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Henüz sayfa eklenmedi.\nKamera veya galeriden fotoğraf ekleyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _images.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _images.removeAt(oldIndex);
                  _images.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final img = _images[index];
                final sizeStr = img.existsSync() ? _formatBytes(img.lengthSync()) : '-';
                final name = p.basename(img.path);

                return Card(
                  key: ValueKey(img.path),
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(img, width: 48, height: 56, fit: BoxFit.cover),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            child: Text(
                              '#${index + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      'Sayfa ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sizeStr,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => setState(() => _images.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. AKSİYON BUTONU (TOPLAM BOYUTU VE HEDEFİ GÖSTEREN)
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
                  '${_images.length} Sayfayı Optimize PDF Yap (${_formatBytes(totalBytes)})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
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