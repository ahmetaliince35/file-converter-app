import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ==========================================
// 1. MODEL VE DÜZEN ENUM'I
// ==========================================
class ResimSayfasi {
  final String id;
  final File dosya;

  ResimSayfasi({required this.id, required this.dosya});
}

/// [satir] x [sutun] düzen tanımı
enum SayfaDizilimi {
  birTek(1, 1, '1 Resim (Tam)'),
  ikiYanYana(1, 2, '2 Kolon (Yan Yana)'),
  ikiUstUste(2, 1, '2 Satır (Alt Alta)'),
  dortKare(2, 2, '2x2 (Kare Izgara)'),
  dortYanYana(1, 4, '4 Kolon (Yan Yana)'),
  altiYatay(2, 3, '2 Satır x 3 Kolon'),
  altiDikey(3, 2, '3 Satır x 2 Kolon');

  final int satir;
  final int sutun;
  final String baslik;

  const SayfaDizilimi(this.satir, this.sutun, this.baslik);

  int get kapasite => satir * sutun;
}

// ==========================================
// 2. DÜZENLEME VE ÇOKLU RESİM EKRANI
// ==========================================
class ImageToPdfScreen extends StatefulWidget {
  final List<File>? initialImages;

  const ImageToPdfScreen({super.key, this.initialImages});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<ResimSayfasi> _sayfalar = [];
  final ImagePicker _picker = ImagePicker();
  bool _isConverting = false;

  // Varsayılan düzen
  SayfaDizilimi _secilenDizilim = SayfaDizilimi.birTek;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      for (var file in widget.initialImages!) {
        _sayfalar.add(
          ResimSayfasi(
            id: DateTime.now().microsecondsSinceEpoch.toString() + file.path,
            dosya: file,
          ),
        );
      }
    }
  }

  Future<void> _resimleriSec() async {
    final List<XFile> secilenler = await _picker.pickMultiImage();
    if (secilenler.isNotEmpty) {
      setState(() {
        for (var xFile in secilenler) {
          _sayfalar.add(
            ResimSayfasi(
              id: DateTime.now().microsecondsSinceEpoch.toString() + xFile.name,
              dosya: File(xFile.path),
            ),
          );
        }
      });
    }
  }

  void _sayfaCikar(int index) {
    setState(() {
      _sayfalar.removeAt(index);
    });
  }

  Future<void> _pdfOlustur() async {
    if (_sayfalar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir resim seçin.')),
      );
      return;
    }

    setState(() => _isConverting = true);

    try {
      final pdf = pw.Document();
      final imageFiles = _sayfalar.map((s) => s.dosya).toList();
      final int sayfaKapasitesi = _secilenDizilim.kapasite;

      for (int i = 0; i < imageFiles.length; i += sayfaKapasitesi) {
        final chunk = imageFiles.sublist(
          i,
          i + sayfaKapasitesi > imageFiles.length ? imageFiles.length : i + sayfaKapasitesi,
        );

        final List<pw.MemoryImage> memImages = [];
        for (final file in chunk) {
          final bytes = await file.readAsBytes();
          memImages.add(pw.MemoryImage(bytes));
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: _secilenDizilim == SayfaDizilimi.birTek
                ? pw.EdgeInsets.zero
                : const pw.EdgeInsets.all(12),
            build: (context) {
              return _buildGridMatrix(memImages, _secilenDizilim);
            },
          ),
        );
      }

      final outputDir = await getApplicationDocumentsDirectory();
      final dosyaAdi = 'Birlestirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final kaydedilenDosya = File('${outputDir.path}/$dosyaAdi');

      await kaydedilenDosya.writeAsBytes(await pdf.save());

      if (!mounted) return;
      Navigator.pop(context, kaydedilenDosya);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata oluştu: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  /// Satır ve Kolon matrisini dinamik olarak çizen fonksiyon
  pw.Widget _buildGridMatrix(List<pw.MemoryImage> images, SayfaDizilimi dizilim) {
    if (dizilim == SayfaDizilimi.birTek) {
      return pw.Center(
        child: pw.Image(images.first, fit: pw.BoxFit.contain),
      );
    }

    final int satirSayisi = dizilim.satir;
    final int sutunSayisi = dizilim.sutun;

    return pw.Column(
      children: List.generate(satirSayisi, (rowIndex) {
        return pw.Expanded(
          child: pw.Row(
            children: List.generate(sutunSayisi, (colIndex) {
              final int imageIndex = (rowIndex * sutunSayisi) + colIndex;

              if (imageIndex < images.length) {
                return pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Center(
                      child: pw.Image(
                        images[imageIndex],
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                );
              } else {
                // Eğer sayfada resim eksik kaldıysa orayı boş alan bırak
                return pw.Expanded(child: pw.Container());
              }
            }),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resim to PDF (${_sayfalar.length} Resim)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: 'Yeni Resim Ekle',
            onPressed: _isConverting ? null : _resimleriSec,
          ),
        ],
      ),
      body: _isConverting
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF derleniyor, lütfen bekleyin...'),
          ],
        ),
      )
          : _sayfalar.isEmpty
          ? Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Resimleri Seç'),
          onPressed: _resimleriSec,
        ),
      )
          : Column(
        children: [
          // DİNAMİK SATIR / KOLON YERLEŞİM AYARI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Row(
              children: [
                const Icon(Icons.view_quilt_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Sayfa Düzeni:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SayfaDizilimi>(
                        value: _secilenDizilim,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: SayfaDizilimi.values.map((dizilim) {
                          return DropdownMenuItem<SayfaDizilimi>(
                            value: dizilim,
                            child: Row(
                              children: [
                                Icon(
                                  dizilim.sutun > dizilim.satir
                                      ? Icons.view_column_rounded
                                      : Icons.view_stream_rounded,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dizilim.baslik,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (yeni) {
                          if (yeni != null) {
                            setState(() => _secilenDizilim = yeni);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SIRALANABİLİR RESİM LİSTESİ
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: _sayfalar.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final eleman = _sayfalar.removeAt(oldIndex);
                  _sayfalar.insert(newIndex, eleman);
                });
              },
              itemBuilder: (context, index) {
                final sayfa = _sayfalar[index];
                return Card(
                  key: ValueKey(sayfa.id),
                  elevation: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            sayfa.dosya,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    title: Text('Resim ${index + 1}'),
                    subtitle: Text(
                      sayfa.dosya.path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Kaldır',
                          onPressed: () => _sayfaCikar(index),
                        ),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _sayfalar.isNotEmpty
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(
              '${_sayfalar.length} RESMİ PDF YAP (${_secilenDizilim.baslik})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _isConverting ? null : _pdfOlustur,
          ),
        ),
      )
          : null,
    );
  }
}

// ==========================================
// 3. STATİK SINIF (HomeScreen Uyumluluğu)
// ==========================================
class ImageToPdfConverter {
  static Future<File> convert(File inputFile) async {
    return convertMultiple([inputFile]);
  }

  static Future<File> convertMultiple(List<File> inputFiles) async {
    final doc = pw.Document();

    for (final file in inputFiles) {
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final baseName = inputFiles.first.uri.pathSegments.last.split('.').first;
    final outFile = File('${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await outFile.writeAsBytes(await doc.save());
    return outFile;
  }
}