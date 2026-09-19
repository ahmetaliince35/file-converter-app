import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as px;

enum CompressionLevel {
  low(quality: 80, scale: 1.5, label: 'Hafif Sıkıştırma (Yüksek Kalite)'),
  medium(quality: 60, scale: 1.2, label: 'Önerilen (Dengeli Boyut ve Netlik)'),
  high(quality: 40, scale: 0.9, label: 'Yüksek Sıkıştırma (Minimum Boyut)');

  final int quality;
  final double scale;
  final String label;

  const CompressionLevel({
    required this.quality,
    required this.scale,
    required this.label,
  });
}

class CompressionResult {
  final File compressedFile;
  final int originalSizeBytes;
  final int newSizeBytes;

  CompressionResult({
    required this.compressedFile,
    required this.originalSizeBytes,
    required this.newSizeBytes,
  });

  double get savingsPercentage {
    if (originalSizeBytes == 0) return 0.0;
    final diff = originalSizeBytes - newSizeBytes;
    return (diff / originalSizeBytes) * 100;
  }
}

class PdfCompressorService {
  /// PDF'i optimize edip sıkıştırılmış yeni halini döndürür
  static Future<CompressionResult> compressPdf({
    required File sourceFile,
    required CompressionLevel level,
    Function(int current, int total)? onProgress,
  }) async {
    final originalSize = await sourceFile.length();
    final document = await px.PdfDocument.openFile(sourceFile.path);
    final totalPages = document.pagesCount;

    final outputPdf = pw.Document();

    for (int i = 1; i <= totalPages; i++) {
      if (onProgress != null) {
        onProgress(i, totalPages);
      }

      final page = await document.getPage(i);
      final renderWidth = (page.width * level.scale).toInt();
      final renderHeight = (page.height * level.scale).toInt();

      final pageImage = await page.render(
        width: renderWidth.toDouble(),
        height: renderHeight.toDouble(),
        format: px.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage == null) continue;

      // Arka planda JPEG sıkıştırması
      final compressedJpgBytes = await compute(
        _compressImageWorker,
        _CompressTask(
          rawBytes: pageImage.bytes,
          targetQuality: level.quality,
        ),
      );

      final imageProvider = pw.MemoryImage(compressedJpgBytes);
      outputPdf.addPage(
        pw.Page(
          pageFormat: pw_pdf.PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(imageProvider, fit: pw.BoxFit.fill),
            );
          },
        ),
      );
    }

    await document.close();

    final tempDir = await getTemporaryDirectory();
    final baseName = p.basenameWithoutExtension(sourceFile.path);
    final outFileName = '${baseName}_sikistirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File('${tempDir.path}/$outFileName');

    final savedBytes = await outputPdf.save();
    await outFile.writeAsBytes(savedBytes);

    return CompressionResult(
      compressedFile: outFile,
      originalSizeBytes: originalSize,
      newSizeBytes: outFile.lengthSync(),
    );
  }
}

class _CompressTask {
  final Uint8List rawBytes;
  final int targetQuality;

  _CompressTask({required this.rawBytes, required this.targetQuality});
}

Uint8List _compressImageWorker(_CompressTask task) {
  final decoded = img.decodeImage(task.rawBytes);
  if (decoded == null) return task.rawBytes;

  // JPEG olarak seçilen kalitede tekrar kodla
  final jpgBytes = img.encodeJpg(decoded, quality: task.targetQuality);
  return Uint8List.fromList(jpgBytes);
}