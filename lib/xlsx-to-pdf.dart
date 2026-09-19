import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class XlsxToPdfConverter {
  /// Her sayfayı (sheet) ayrı bir tablo olarak PDF'e basar.
  /// Not: Formüller "hesaplanmış değer" olarak, grafik/pivot gibi ileri
  /// düzey öğeler ise desteklenmeden basitçe atlanır.
  static Future<File> convert(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final workbook = xls.Excel.decodeBytes(bytes);
    final doc = pw.Document();

    for (final sheetName in workbook.tables.keys) {
      final sheet = workbook.tables[sheetName]!;
      if (sheet.maxRows == 0) continue;

      final rows = <List<String>>[];
      for (final row in sheet.rows) {
        rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
      }
      if (rows.isEmpty) continue;

      final headers = rows.first;
      final body = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => pw.Text(
            sheetName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: body,
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final baseName = inputFile.uri.pathSegments.last.split('.').first;
    final outFile = File('${dir.path}/$baseName.pdf');
    await outFile.writeAsBytes(await doc.save());
    return outFile;
  }
}