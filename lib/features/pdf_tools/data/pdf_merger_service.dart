import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/files/temp_file_manager.dart';

class PdfMergerService {
  /// Verilen PDF dosyalarını listedeki sıra ile birbirinin arkasına ekler.
  /// İçerikleri, fontları, sayfa boyutları korunur.
  static Future<File> mergePdfFiles(List<File> pdfFiles) async {
    if (pdfFiles.isEmpty) {
      throw Exception("Birleştirilecek PDF seçilmedi.");
    }

    final PdfDocument outputPdf = PdfDocument();

    try {
      for (final file in pdfFiles) {
        if (!await file.exists()) continue;

        final List<int> bytes = await file.readAsBytes();
        final PdfDocument inputPdf = PdfDocument(inputBytes: bytes);

        try {
          for (int i = 0; i < inputPdf.pages.count; i++) {
            final PdfPage sourcePage = inputPdf.pages[i];
            final PdfTemplate template = sourcePage.createTemplate();

            // Sayfa boyutunu ve marjını her eklenen sayfa için ayarla
            outputPdf.pageSettings.size = sourcePage.size;
            outputPdf.pageSettings.margins.all = 0;

            final PdfPage newPage = outputPdf.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
            );
          }
        } finally {
          inputPdf.dispose();
        }
      }

      // Dosyayı converter_cache içine yazarak depolama hijyenini koruyoruz:
      final workingDir = await TempFileManager.workingDir;
      final fileName = 'Birlestirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File('${workingDir.path}/$fileName');

      final List<int> outBytes = await outputPdf.save();
      await outputFile.writeAsBytes(outBytes);

      return outputFile;
    } finally {
      outputPdf.dispose();
    }
  }
}