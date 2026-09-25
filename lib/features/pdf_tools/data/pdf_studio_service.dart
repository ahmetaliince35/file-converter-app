import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import '../../../../core/files/temp_file_manager.dart';

class PdfStudioService {
  /// Birden fazla PDF dosyasını sıralı tek bir PDF olarak birleştirir
  static Future<File> mergePdfs({
    required List<File> pdfFiles,
    void Function(int current, int total)? onProgress,
  }) async {
    if (pdfFiles.length < 2) {
      throw Exception('Birleştirme için en az 2 PDF dosyası gereklidir.');
    }

    final outputDoc = sf_pdf.PdfDocument();

    for (int i = 0; i < pdfFiles.length; i++) {
      onProgress?.call(i + 1, pdfFiles.length);

      final bytes = await pdfFiles[i].readAsBytes();
      final inputDoc = sf_pdf.PdfDocument(inputBytes: bytes);

      for (int pageIndex = 0; pageIndex < inputDoc.pages.count; pageIndex++) {
        final pageTemplate = inputDoc.pages[pageIndex].createTemplate();
        outputDoc.pages.add().graphics.drawPdfTemplate(
          pageTemplate,
          Offset.zero,
        );
      }
      inputDoc.dispose();
    }

    final List<int> savedBytes = await outputDoc.save();
    outputDoc.dispose();

    final workingDir = await TempFileManager.workingDir;
    final outPath = p.join(
      workingDir.path,
      'birlestirilmis_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(savedBytes, flush: true);

    return outFile;
  }

  /// PDF dosyasından sadece seçilen sayfa indekslerini ayıklayarak yeni bir PDF oluşturur
  static Future<File> splitPdfPages({
    required File sourcePdf,
    required List<int> selectedPageIndices, // 0-tabanlı indeksler
  }) async {
    if (selectedPageIndices.isEmpty) {
      throw Exception('Ayıklanacak en az bir sayfa seçilmelidir.');
    }

    final bytes = await sourcePdf.readAsBytes();
    final inputDoc = sf_pdf.PdfDocument(inputBytes: bytes);
    final outputDoc = sf_pdf.PdfDocument();

    final sortedIndices = List<int>.from(selectedPageIndices)..sort();

    for (final pageIndex in sortedIndices) {
      if (pageIndex >= 0 && pageIndex < inputDoc.pages.count) {
        final pageTemplate = inputDoc.pages[pageIndex].createTemplate();
        outputDoc.pages.add().graphics.drawPdfTemplate(
          pageTemplate,
          const Offset(0, 0),
        );
      }
    }

    inputDoc.dispose();
    final List<int> savedBytes = await outputDoc.save();
    outputDoc.dispose();

    final workingDir = await TempFileManager.workingDir;
    final outPath = p.join(
      workingDir.path,
      'ayiklanan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(savedBytes, flush: true);

    return outFile;
  }

  /// PDF dosyasının toplam sayfa adedini döner
  static Future<int> getPageCount(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (e) {
      debugPrint('[PDF_PAGE_COUNT_ERROR] $e');
      return 0;
    }
  }
}