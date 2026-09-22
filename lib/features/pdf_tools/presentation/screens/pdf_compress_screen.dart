import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../data/pdf_compressor_service.dart';

class PdfCompressScreen extends StatefulWidget {
  final File file;

  const PdfCompressScreen({super.key, required this.file});

  @override
  State<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends State<PdfCompressScreen> {
  CompressionLevel _selectedLevel = CompressionLevel.medium;
  bool _isProcessing = false;
  int _currentPage = 0;
  int _totalPages = 0;
  CompressionResult? _result;

  String _formatBytes(int bytes) {
    return (bytes / (1024 * 1024)).toStringAsFixed(2);
  }

  Future<void> _startCompression() async {
    setState(() {
      _isProcessing = true;
      _currentPage = 0;
      _totalPages = 0;
    });

    try {
      final res = await PdfCompressorService.compressPdf(
        sourceFile: widget.file,
        level: _selectedLevel,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sıkıştırma hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final originalSizeMb = _formatBytes(widget.file.lengthSync());
    final fileName = p.basename(widget.file.path);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Boyutu Küçült'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dosya Bilgi Kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mevcut Boyut: $originalSizeMb MB',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_result == null && !_isProcessing) ...[
              const Text(
                'Sıkıştırma Seviyesi Seçin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...CompressionLevel.values.map((lvl) {
                final isSelected = _selectedLevel == lvl;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.indigo.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.indigo : Colors.grey.shade300,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: RadioListTile<CompressionLevel>(
                    value: lvl,
                    groupValue: _selectedLevel,
                    activeColor: Colors.indigo,
                    title: Text(
                      lvl.name == 'medium' ? 'Önerilen Sıkıştırma' : (lvl.name == 'low' ? 'Hafif Sıkıştırma' : 'Yüksek Sıkıştırma'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(lvl.label, style: const TextStyle(fontSize: 12)),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLevel = val);
                    },
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _startCompression,
                icon: const Icon(Icons.compress_rounded),
                label: const Text('Şimdi Sıkıştır', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],

            if (_isProcessing) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              Text(
                _totalPages > 0
                    ? 'Sayfa işleniyor: $_currentPage / $_totalPages'
                    : 'PDF analiz ediliyor...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Görseller optimize ediliyor, lütfen bekleyin...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],

            // Sonuç Başarı Kartı
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Sıkıştırma Tamamlandı!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Önceki Boyut', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text('$originalSizeMb MB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                        Column(
                          children: [
                            const Text('Yeni Boyut', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatBytes(_result!.newSizeBytes)} MB',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '%${_result!.savingsPercentage.clamp(0, 100).toStringAsFixed(1)} Tasarruf Sağlandı',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context, _result!.compressedFile);
                },
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Tamamla ve Listeye Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}