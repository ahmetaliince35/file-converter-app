import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as px;

import '../../../../core/files/temp_file_manager.dart';

enum CompressionLevel {
  low(quality: 80, scale: 1.4, label: 'Hafif Sıkıştırma (Yüksek Kalite)'),
  medium(quality: 60, scale: 1.1, label: 'Önerilen (Dengeli Boyut ve Netlik)'),
  high(quality: 40, scale: 0.85, label: 'Yüksek Sıkıştırma (Minimum Boyut)');

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

    try {
      for (int i = 1; i <= totalPages; i++) {
        onProgress?.call(i, totalPages);

        final page = await document.getPage(i);
        final renderWidth = (page.width * level.scale).toInt();
        final renderHeight = (page.height * level.scale).toInt();

        // format: jpeg doğrudan native Pdfium seviyesinde hafif bayt üretir
        final pageImage = await page.render(
          width: renderWidth.toDouble(),
          height: renderHeight.toDouble(),
          format: px.PdfPageImageFormat.jpeg,
          quality: level.quality,
        );
        await page.close();

        if (pageImage == null) continue;

        // Gerekirse ek sıkıştırma izolatörüne gönder
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
    } finally {
      // Hata olsa bile Pdfium belgesini kapatıp native RAM'i serbest bırakıyoruz:
      await document.close();
    }

    // TempFileManager çalışma dizinine yazarak depolama hijyenini koruyoruz:
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(sourceFile.path);
    final outFileName = '${baseName}_sikistirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File('${workingDir.path}/$outFileName');

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

  final jpgBytes = img.encodeJpg(decoded, quality: task.targetQuality);
  return Uint8List.fromList(jpgBytes);
}