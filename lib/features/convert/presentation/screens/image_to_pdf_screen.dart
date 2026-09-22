import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/files/temp_file_manager.dart';
import '../../data/image_to_pdf_converter.dart';

class ResimSayfasi {
  final String id;
  final File dosya;
  ResimSayfasi({required this.id, required this.dosya});
}

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<ResimSayfasi> _sayfalar = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _isPicking = false; // Çift tıklama kalkanı
  int _currentPage = 0;
  int _totalPages = 0;

  Future<void> _resimleriSec() async {
    if (_isPicking || _isProcessing) return;
    _isPicking = true;

    try {
      final List<XFile> secilenler = await _picker.pickMultiImage();
      if (secilenler.isNotEmpty && mounted) {
        setState(() {
          for (var xFile in secilenler) {
            _sayfalar.add(
              ResimSayfasi(
                id: '${DateTime.now().microsecondsSinceEpoch}_${xFile.name}',
                dosya: File(xFile.path),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Resim seçim hatası: $e');
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _pdfYap() async {
    if (_sayfalar.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _currentPage = 0;
      _totalPages = _sayfalar.length;
    });

    try {
      final files = _sayfalar.map((s) => s.dosya).toList();

      final File pdfFile = await ImageToPdfConverter.convert(
        files,
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
      Navigator.pop(context, pdfFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Kullanıcı vazgeçip geri çıktığında arkada seçili kalan ham resimleri temizle
  Future<void> _iptalVeTemizle() async {
    final files = _sayfalar.map((s) => s.dosya).toList();
    _sayfalar.clear();
    await TempFileManager.deleteFiles(files);
  }

  @override
  void dispose() {
    _iptalVeTemizle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) {
          _iptalVeTemizle();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Resimleri PDF Yap (${_sayfalar.length})'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              tooltip: 'Fotoğraf Ekle',
              onPressed: _isProcessing ? null : _resimleriSec,
            ),
          ],
        ),
        body: _isProcessing
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 240,
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
                    : 'Görseller hazırlanıyor...',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Çözünürlük optimize ediliyor & PDF derleniyor...',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        )
            : _sayfalar.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined, size: 70, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('PDF\'e dönüştürülecek fotoğrafları seçin.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Fotoğrafları Seç'),
                onPressed: _resimleriSec,
              ),
            ],
          ),
        )
            : ReorderableListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _sayfalar.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) newIndex -= 1;
              final item = _sayfalar.removeAt(oldIndex);
              _sayfalar.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final sayfa = _sayfalar[index];
            final name = p.basename(sayfa.dosya.path);

            return Card(
              key: ValueKey(sayfa.id),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    sayfa.dosya,
                    width: 48,
                    height: 56,
                    cacheWidth: 140, // RAM taşmasını önleyen kritik satır
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Sayfa ${index + 1}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final silinecek = _sayfalar.removeAt(index);
                        setState(() {});
                        await TempFileManager.deleteFile(silinecek.dosya);
                      },
                    ),
                    const Icon(Icons.drag_handle),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: _sayfalar.isNotEmpty
            ? SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text(
                'PDF\'E DÖNÜŞTÜR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isProcessing ? null : _pdfYap,
            ),
          ),
        )
            : null,
      ),
    );
  }
}