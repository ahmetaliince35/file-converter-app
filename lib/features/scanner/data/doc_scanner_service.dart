import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;

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
    int quality = 70, // %70 JPEG kalitesi (okunabilirlik bozulmaz, boyut çakılır)
    Function(int current, int total)? onProgress,
  }) async {
    final List<Uint8List> processedImages = [];

    for (int i = 0; i < imageFiles.length; i++) {
      if (onProgress != null) {
        onProgress(i + 1, imageFiles.length);
      }

      final rawBytes = await imageFiles[i].readAsBytes();

      // Arka planda hem çözünürlüğü A4 standardına indirir hem de sıkıştırır
      final processedBytes = await compute(_optimizeAndResizeWorker, {
        'bytes': rawBytes,
        'quality': quality,
        'filter': filter,
      });

      processedImages.add(processedBytes);
    }

    return await _generateA4Pdf(processedImages);
  }

  static Future<File> _generateA4Pdf(List<Uint8List> imagesBytes) async {
    final pdf = pw.Document();

    for (final bytes in imagesBytes) {
      final imageProvider = pw.MemoryImage(bytes);
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

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/belge_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());

    return outFile;
  }
}

/// Çözünürlüğü kıran ve boyutu asıl düşüren fonksiyon
Uint8List _optimizeAndResizeWorker(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int quality = params['quality'];
  final DocumentFilterMode filter = params['filter'];

  img.Image? image = img.decodeImage(rawBytes);
  if (image == null) return rawBytes;

  // 1. BOYUTU DÜŞÜRME (DOWNSCALE):
  // Telefon kamerasının 4000x3000 piksel devasa boyutunu A4 okunabilir sınırına (maksimum 1400px) çekiyoruz.
  // Bu işlem tek başına dosya boyutunu %70 küçültür!
  const int maxDimension = 1400;
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDimension);
    } else {
      image = img.copyResize(image, height: maxDimension);
    }
  }

  // 2. FİLTRE (İsteğe bağlı netleştirme)
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