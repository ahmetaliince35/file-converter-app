import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/temp_file_manager.dart';

enum DocumentFilterMode {
  none,
  enhanceContrast,
  blackAndWhite,
}

class DocScannerService {
  /// Fotoğrafları hem boyut olarak küçültür hem de A4 PDF yapar
  static Future<File> createScannedPdf({
    required List<File> imageFiles,
    DocumentFilterMode filter = DocumentFilterMode.enhanceContrast,
    int quality = 70, // %70 JPEG kalitesi (okunabilirlik korunur, boyut düşer)
    Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i + 1, imageFiles.length);

      final rawBytes = await imageFiles[i].readAsBytes();

      // Arka planda çözünürlüğü A4 standardına indirip sıkıştırır
      final processedBytes = await compute(_optimizeAndResizeWorker, {
        'bytes': rawBytes,
        'quality': quality,
        'filter': filter,
      });

      final imageProvider = pw.MemoryImage(processedBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pw_pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(10),
          build: (context) {
            return pw.Center(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    // Dosyayı converter_cache içine yazarak depolama hijyenini koruyoruz:
    final workingDir = await TempFileManager.workingDir;
    final outPath = '${workingDir.path}/belge_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());

    return outFile;
  }
}

/// Çözünürlüğü düzenleyen ve boyutu asıl düşüren arka plan fonksiyonu
Uint8List _optimizeAndResizeWorker(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int quality = params['quality'];
  final DocumentFilterMode filter = params['filter'];

  img.Image? image = img.decodeImage(rawBytes);
  if (image == null) return rawBytes;

  // 1. BOYUTU DÜŞÜRME (DOWNSCALE):
  // Telefon kamerasının 4000x3000 piksel devasa boyutunu A4 okunabilir sınırına (maksimum 1400px) çekiyoruz.
  const int maxDimension = 1400;
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDimension);
    } else {
      image = img.copyResize(image, height: maxDimension);
    }
  }

  // 2. FİLTRE (Netleştirme / Belge modu)
  if (filter == DocumentFilterMode.enhanceContrast) {
    image = img.adjustColor(image, contrast: 1.3, brightness: 1.05);
  } else if (filter == DocumentFilterMode.blackAndWhite) {
    image = img.grayscale(image);
    image = img.adjustColor(image, contrast: 1.5, brightness: 1.1);
  }

  // 3. KALİTE SIKIŞTIRMASI (JPEG ENCODE)
  final jpgBytes = img.encodeJpg(image, quality: quality);
  return Uint8List.fromList(jpgBytes);
}