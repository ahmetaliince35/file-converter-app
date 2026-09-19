import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import '../services/pdf-page_splitter_service.dart';

class PdfSplitScreen extends StatefulWidget {
  const PdfSplitScreen({super.key});

  @override
  State<PdfSplitScreen> createState() => _PdfSplitScreenState();
}

class _PdfSplitScreenState extends State<PdfSplitScreen> {
  File? _selectedFile;
  Uint8List? _fileBytes;
  int _totalPages = 0;
  final Set<int> _selectedIndices = {}; // 0-based
  bool _isLoading = false;

  // Render edilmiş baytları önbellekte tutuyoruz (tekrar render etmemek için)
  final Map<int, Uint8List> _thumbnailBytesCache = {};

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => _isLoading = true);

      try {
        final count = await PdfSplitterService.getPageCount(file);
        final bytes = await file.readAsBytes();

        setState(() {
          _selectedFile = file;
          _fileBytes = bytes;
          _totalPages = count;
          _selectedIndices.clear();
          _thumbnailBytesCache.clear();
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF okunamadı: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Tek bir PDF sayfasını PNG baytlarına dönüştüren asenkron fonksiyon
  Future<Uint8List> _renderPageToPng(int pageIndex, double dpi) async {
    if (_fileBytes == null) throw Exception("Dosya yüklenemedi");

    // Printing.raster bir Stream döner, .first ile ilk (ve tek) sayfayı alırız
    final raster = await Printing.raster(_fileBytes!, pages: [pageIndex], dpi: dpi).first;
    // toPng() bir Future<Uint8List> döner
    return await raster.toPng();
  }

  // Sayfayı tam ekran büyüterek detaylı inceleme diyaloğu
  void _showPagePreviewDialog(int pageIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                title: Text('Sayfa ${pageIndex + 1} Önizleme'),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Flexible(
                child: Container(
                  color: Colors.white,
                  child: InteractiveViewer(
                    // Kullanıcı sayfayı parmaklarıyla zoomlayabilir
                    child: FutureBuilder<Uint8List>(
                      future: _renderPageToPng(pageIndex, 144),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Center(child: Text('Sayfa yüklenemedi'));
                        }
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _ayiklaVeKaydet() async {
    if (_selectedFile == null || _selectedIndices.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final File resultFile = await PdfSplitterService.extractPages(
        sourcePdf: _selectedFile!,
        selectedPages: _selectedIndices.toList(),
      );

      if (!mounted) return;
      Navigator.pop(context, resultFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Sayfa Ayıkla & Böl'),
        actions: [
          if (_totalPages > 0)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIndices.length == _totalPages) {
                    _selectedIndices.clear();
                  } else {
                    _selectedIndices.addAll(List.generate(_totalPages, (i) => i));
                  }
                });
              },
              child: Text(
                _selectedIndices.length == _totalPages ? 'Seçimi Kaldır' : 'Tümünü Seç',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedFile == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_split_rounded, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Sayfalarını ayıklamak istediğin PDF\'i seç.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('PDF Dosyası Seç'),
              onPressed: _pickPdf,
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Dosya Bilgi Kartı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.basename(_selectedFile!.path),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('Toplam: $_totalPages Sayfa'),
              ],
            ),
          ),

          // Küçük Resimli Sayfa Izgarası
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: _totalPages,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndices.contains(index);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIndices.remove(index);
                      } else {
                        _selectedIndices.add(index);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? Colors.indigo.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Tembel Yüklenen Küçük Resim (Thumbnail)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _thumbnailBytesCache.containsKey(index)
                              ? Image.memory(
                            _thumbnailBytesCache[index]!,
                            fit: BoxFit.contain,
                          )
                              : FutureBuilder<Uint8List>(
                            future: _renderPageToPng(index, 72),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                _thumbnailBytesCache[index] = snapshot.data!;
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                );
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                          ),
                        ),

                        // Üst Başlık & Büyüteç Çubuğu
                        Positioned(
                          top: 4,
                          left: 4,
                          right: 4,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.indigo : Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Sayfa ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white.withValues(alpha: 0.9),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.zoom_in, size: 18, color: Colors.black87),
                                  tooltip: 'Büyüt ve İncele',
                                  onPressed: () => _showPagePreviewDialog(index),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Seçildiyse Tik İkonu
                        if (isSelected)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.indigo,
                              child: const Icon(Icons.check, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIndices.isNotEmpty
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download_done_rounded),
            label: Text(
              '${_selectedIndices.length} SAYFAYI AYIKLA VE YENİ PDF YAP',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _isLoading ? null : _ayiklaVeKaydet,
          ),
        ),
      )
          : null,
    );
  }
}