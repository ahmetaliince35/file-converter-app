import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart' as xml;

/// docx dosyaları aslında bir ZIP arşividir; asıl metin
/// "word/document.xml" içinde OOXML formatında bulunur. Bu converter,
/// mammoth.js gibi harici bir JS motoruna veya internete ihtiyaç duymadan,
/// bu XML'i doğrudan Dart ile okuyup PDF'e döker.
///
/// Desteklenen: paragraflar, kalın/italik/altı çizili metin, başlıklar
/// (heading stilleri kabaca büyük/kalın olarak yansıtılır).
/// Desteklenmeyen (v1 kapsamı dışında): tablolar, gömülü resimler,
/// ileri düzey stil/tema bilgisi, dipnotlar.
class DocxToPdfConverter {
  static Future<File> convert(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final documentEntry = archive.files.firstWhere(
          (f) => f.name == 'word/document.xml',
      orElse: () => throw const FormatException(
          'Geçersiz docx: word/document.xml bulunamadı.'),
    );

    final xmlString = String.fromCharCodes(documentEntry.content as List<int>);
    final document = xml.XmlDocument.parse(xmlString);

    final paragraphs = document.findAllElements('w:p');
    final pdfDoc = pw.Document();
    final widgets = <pw.Widget>[];

    for (final p in paragraphs) {
      final isHeading = _isHeading(p);
      final spans = <pw.TextSpan>[];

      for (final run in p.findElements('w:r')) {
        final text = run
            .findElements('w:t')
            .map((t) => t.innerText)
            .join();
        if (text.isEmpty) continue;

        final rPr = run.findElements('w:rPr').firstOrNull;
        final bold = rPr?.findElements('w:b').isNotEmpty ?? false;
        final italic = rPr?.findElements('w:i').isNotEmpty ?? false;
        final underline = rPr?.findElements('w:u').isNotEmpty ?? false;

        spans.add(pw.TextSpan(
          text: text,
          style: pw.TextStyle(
            fontSize: isHeading ? 16 : 11,
            fontWeight: (bold || isHeading) ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
          ),
        ));
      }

      if (spans.isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
      } else {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.RichText(text: pw.TextSpan(children: spans)),
        ));
      }
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => widgets,
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final baseName = inputFile.uri.pathSegments.last.split('.').first;
    final outFile = File('${dir.path}/$baseName.pdf');
    await outFile.writeAsBytes(await pdfDoc.save());
    return outFile;
  }

  static bool _isHeading(xml.XmlElement paragraph) {
    final pPr = paragraph.findElements('w:pPr').firstOrNull;
    final pStyle = pPr?.findElements('w:pStyle').firstOrNull;
    final styleVal = pStyle?.getAttribute('w:val') ?? '';
    return styleVal.toLowerCase().contains('heading') ||
        styleVal.toLowerCase().contains('title');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}