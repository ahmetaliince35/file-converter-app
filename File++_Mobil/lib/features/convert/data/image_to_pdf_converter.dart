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
    int imagesPerPage = 1,
    Function(int current, int total)? onProgress,
  }) async {
    return createScannedPdf(
      imageFiles: imageFiles,
      imagesPerPage: imagesPerPage,
      filter: DocumentFilterMode.none,
      quality: 85,
      onProgress: onProgress,
    );
  }

  /// Fotoğrafları optimize eder ve matris düzeninde A4 PDF sayfalarına yerleştirir
  static Future<File> createScannedPdf({
    required List<File> imageFiles,
    int imagesPerPage = 1,
    DocumentFilterMode filter = DocumentFilterMode.none,
    int quality = 85,
    Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();

    final List<pw.MemoryImage> imageProviders = [];
    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i + 1, imageFiles.length);

      final rawBytes = await imageFiles[i].readAsBytes();

      final processedBytes = await compute(_optimizeAndResizeWorker, {
        'bytes': rawBytes,
        'quality': quality,
        'filter': filter,
      });

      imageProviders.add(pw.MemoryImage(processedBytes));
    }

    final int perPage = imagesPerPage.clamp(1, 9);
    final int totalPages = (imageProviders.length / perPage).ceil();

    for (int pIndex = 0; pIndex < totalPages; pIndex++) {
      final startIndex = pIndex * perPage;
      final endIndex = (startIndex + perPage).clamp(0, imageProviders.length);
      final chunk = imageProviders.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: pw_pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) {
            return _buildPageMatrix(chunk, perPage);
          },
        ),
      );
    }

    final workingDir = await TempFileManager.workingDir;
    final outPath = '${workingDir.path}/gorseller_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());

    return outFile;
  }

  static pw.Widget _buildPageMatrix(List<pw.MemoryImage> images, int perPage) {
    if (perPage == 1) {
      return pw.Center(
        child: pw.Image(images.first, fit: pw.BoxFit.contain),
      );
    }

    if (perPage == 2) {
      return pw.Column(
        children: [
          for (final img in images)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
              ),
            ),
        ],
      );
    }

    if (perPage == 4) {
      return _buildGrid(images, cols: 2, rows: 2);
    }

    if (perPage == 6) {
      return _buildGrid(images, cols: 2, rows: 3);
    }

    if (perPage == 9) {
      return _buildGrid(images, cols: 3, rows: 3);
    }

    return _buildGrid(images, cols: 2, rows: 2);
  }

  static pw.Widget _buildGrid(List<pw.MemoryImage> images, {required int cols, required int rows}) {
    return pw.Column(
      children: List.generate(rows, (r) {
        return pw.Expanded(
          child: pw.Row(
            children: List.generate(cols, (c) {
              final idx = r * cols + c;
              if (idx < images.length) {
                return pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Center(
                      child: pw.Image(images[idx], fit: pw.BoxFit.contain),
                    ),
                  ),
                );
              }
              return pw.Expanded(child: pw.SizedBox());
            }),
          ),
        );
      }),
    );
  }
}

/// Çözünürlüğü düzenleyen ve boyutu düşüren arka plan fonksiyonu
Uint8List _optimizeAndResizeWorker(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int quality = params['quality'];
  final DocumentFilterMode filter = params['filter'] ?? DocumentFilterMode.none;

  img.Image? image = img.decodeImage(rawBytes);
  if (image == null) return rawBytes;

  const int maxDimension = 1600;
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