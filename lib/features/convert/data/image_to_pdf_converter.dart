import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/temp_file_manager.dart';

typedef ConverterProgressCallback = void Function(int current, int total);

class ImageToPdfConverter {
  static Future<File> convert(
      List<File> imageFiles, {
        ConverterProgressCallback? onProgress,
      }) async {
    if (imageFiles.isEmpty) {
      throw Exception('Dönüştürülecek fotoğraf bulunamadı.');
    }

    final pdf = pw.Document();
    final total = imageFiles.length;

    try {
      for (var i = 0; i < total; i++) {
        final file = imageFiles[i];
        onProgress?.call(i + 1, total);

        if (!await file.exists()) continue;

        final rawBytes = await file.readAsBytes();
        final optimizedBytes = await compute(_downscaleWorker, rawBytes);

        final imageProvider = pw.MemoryImage(optimizedBytes);
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
      final outPath = '${workingDir.path}/Resimler_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(await pdf.save());

      return outFile;
    } finally {
      await TempFileManager.deleteFiles(imageFiles);
    }
  }
}

Uint8List _downscaleWorker(Uint8List bytes) {
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  const int maxDimension = 1600;
  if (decoded.width > maxDimension || decoded.height > maxDimension) {
    if (decoded.width > decoded.height) {
      decoded = img.copyResize(decoded, width: maxDimension);
    } else {
      decoded = img.copyResize(decoded, height: maxDimension);
    }
  }

  return Uint8List.fromList(img.encodeJpg(decoded, quality: 75));
}