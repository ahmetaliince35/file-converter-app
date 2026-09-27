import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/temp_file_manager.dart';

enum DocumentFilterMode {
  none,
  magicColor,      // CamScanner Sihirli Renk (arka planı beyazlatır, renkli yazıları parlatır)
  blackAndWhite,   // Temiz Fotokopi / Metin Modu
  grayscale,       // Gri Tonlama
}

class DocScannerService {
  /// Fotoğrafları işler, filtreler ve tek bir A4 PDF dosyasında toplar
  static Future<File> createScannedPdf({
    required List<File> imageFiles,
    required List<int> rotations, // Her görselin dönüş açısı (0, 90, 180, 270)
    DocumentFilterMode filter = DocumentFilterMode.magicColor,
    int quality = 75,
    Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i + 1, imageFiles.length);

      final rawBytes = await imageFiles[i].readAsBytes();
      final rotationAngle = (i < rotations.length) ? rotations[i] : 0;

      // Ağır görsel işleme ana thread'i (UI) dondurmasın diye compute isolate içinde yapılır
      final processedBytes = await compute(_processDocumentWorker, {
        'bytes': rawBytes,
        'quality': quality,
        'filter': filter,
        'rotation': rotationAngle,
      });

      final imageProvider = pw.MemoryImage(processedBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pw_pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          build: (context) {
            return pw.Center(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final workingDir = await TempFileManager.workingDir;
    final outPath = '${workingDir.path}/tarama_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());

    return outFile;
  }
}

/// Arka plan görsel işleme motoru
Uint8List _processDocumentWorker(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int quality = params['quality'];
  final DocumentFilterMode filter = params['filter'];
  final int rotation = params['rotation'] ?? 0;

  img.Image? image = img.decodeImage(rawBytes);
  if (image == null) return rawBytes;

  // 1. Döndürme işlemi (varsa)
  if (rotation == 90) {
    image = img.copyRotate(image, angle: 90);
  } else if (rotation == 180) {
    image = img.copyRotate(image, angle: 180);
  } else if (rotation == 270) {
    image = img.copyRotate(image, angle: 270);
  }

  // 2. Boyutlandırma (A4 okunabilirlik standardı - max 1600px)
  const int maxDimension = 1600;
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDimension, interpolation: img.Interpolation.linear);
    } else {
      image = img.copyResize(image, height: maxDimension, interpolation: img.Interpolation.linear);
    }
  }

  // 3. CamScanner Filtre Algoritmaları
  switch (filter) {
    case DocumentFilterMode.magicColor:
    // Arka plandaki sarı/gri gölgeleri aydınlat, yazıları koyulaştır ve doygunluğu koru
      image = img.adjustColor(
        image,
        contrast: 1.45,
        brightness: 1.15,
        saturation: 1.1,
      );
      break;

    case DocumentFilterMode.blackAndWhite:
    // Yüksek kontrastlı fotokopi/metin modu
      image = img.grayscale(image);
      image = img.adjustColor(
        image,
        contrast: 1.8,
        brightness: 1.25,
      );
      break;

    case DocumentFilterMode.grayscale:
      image = img.grayscale(image);
      image = img.adjustColor(
        image,
        contrast: 1.2,
        brightness: 1.05,
      );
      break;

    case DocumentFilterMode.none:
      break;
  }

  final jpgBytes = img.encodeJpg(image, quality: quality);
  return Uint8List.fromList(jpgBytes);
}