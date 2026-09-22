import 'dart:io';
import 'package:flutter/material.dart'; // Offset sınıfı buradan gelir
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfMergerService {
  /// Verilen PDF dosyalarını listedeki sıra ile birbirinin arkasına ekler.
  /// İçerikleri, fontları, sayfa boyutları zerre bozulmaz.
  static Future<File> mergePdfFiles(List<File> pdfFiles) async {
    if (pdfFiles.isEmpty) {
      throw Exception("Birleştirilecek PDF seçilmedi.");
    }

    // Ana çıktı dökümanı
    final PdfDocument outputPdf = PdfDocument();

    for (final file in pdfFiles) {
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument inputPdf = PdfDocument(inputBytes: bytes);

      // PDF'in her sayfasını orijinal boyutuyla yeni dokümana kopyalar
      for (int i = 0; i < inputPdf.pages.count; i++) {
        final PdfPage sourcePage = inputPdf.pages[i];
        final PdfTemplate template = sourcePage.createTemplate();

        // Orijinal sayfa boyutunu korumak için yeni sayfanın ayarlarını eşitle
        outputPdf.pageSettings.size = sourcePage.size;
        outputPdf.pageSettings.margins.all = 0;

        // Sayfayı yeni dokümana ekle ve template'i (0,0) noktasına çiz
        outputPdf.pages.add().graphics.drawPdfTemplate(
          template,
          Offset.zero,
        );
      }

      inputPdf.dispose();
    }

    final outputDir = await getTemporaryDirectory();
    final fileName = 'Birlestirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outputFile = File('${outputDir.path}/$fileName');

    final List<int> outBytes = await outputPdf.save();
    await outputFile.writeAsBytes(outBytes);
    outputPdf.dispose();

    return outputFile;
  }
}