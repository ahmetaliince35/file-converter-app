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

class ImageToPdfConverter {
  /// HomeViewModel tarafından doğrudan toplu dönüştürme için çağrılan standart metot
  static Future<File> convert(
      List<File> imageFiles, {
        Function(int current, int total)? onProgress,
      }) async {
    return createScannedPdf(
      imageFiles: imageFiles,
      filter: DocumentFilterMode.enhanceContrast,
      quality: 75,
      onProgress: onProgress,
    );
  }

  /// Fotoğrafları hem boyut olarak optimize eder hem de A4 PDF yapar
  static Future<File> createScannedPdf({
    required List<File> imageFiles,
    DocumentFilterMode filter = DocumentFilterMode.enhanceContrast,
    int quality = 70,
    Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i + 1, imageFiles.length);

      final rawBytes = await imageFiles[i].readAsBytes();

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

    final workingDir = await TempFileManager.workingDir;
    final outPath = '${workingDir.path}/belge_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());

    return outFile;
  }
}

/// Çözünürlüğü düzenleyen ve boyutu düşüren arka plan fonksiyonu
Uint8List _optimizeAndResizeWorker(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int quality = params['quality'];
  final DocumentFilterMode filter = params['filter'];

  img.Image? image = img.decodeImage(rawBytes);
  if (image == null) return rawBytes;

  const int maxDimension = 1400;
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDimension);
    } else {
      image = img.copyResize(image, height: maxDimension);
    }
  }

  if (filter == DocumentFilterMode.enhanceContrast) {
    image = img.adjustColor(image, contrast: 1.3, brightness: 1.05);
  } else if (filter == DocumentFilterMode.blackAndWhite) {
    image = img.grayscale(image);
    image = img.adjustColor(image, contrast: 1.5, brightness: 1.1);
  }

  final jpgBytes = img.encodeJpg(image, quality: quality);
  return Uint8List.fromList(jpgBytes);
}