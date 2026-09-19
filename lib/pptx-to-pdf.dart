import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart' as xml;

/// pptx dosyaları da bir ZIP arşividir; her slayt "ppt/slides/slideN.xml"
/// içindedir. Bu converter her slaytın metnini çıkarıp PDF'te ayrı bir
/// sayfa olarak basar.
///
/// v1 kapsamı: sadece metin çıkarımı. Slayt üzerindeki tam konumlandırma,
/// animasyonlar, geçişler ve gömülü grafikler desteklenmez — bunlar mobil
/// ortamda internetsiz %100 sadakatle render edilemeyecek kadar karmaşık.
/// Gömülü resimler v2'de eklenebilir (ppt/media altında dururlar).
class PptxToPdfConverter {
  static Future<File> convert(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final slideFiles = archive.files
        .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) => _slideNumber(a.name).compareTo(_slideNumber(b.name)));

    if (slideFiles.isEmpty) {
      throw const FormatException('Geçersiz pptx: slayt bulunamadı.');
    }

    final pdfDoc = pw.Document();

    for (var i = 0; i < slideFiles.length; i++) {
      final xmlString = String.fromCharCodes(slideFiles[i].content as List<int>);
      final slideXml = xml.XmlDocument.parse(xmlString);

      final texts = slideXml
          .findAllElements('a:t')
          .map((e) => e.innerText)
          .where((t) => t.trim().isNotEmpty)
          .toList();

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Slayt ${i + 1}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 12),
              ...texts.map(
                    (t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(t, style: const pw.TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final baseName = inputFile.uri.pathSegments.last.split('.').first;
    final outFile = File('${dir.path}/$baseName.pdf');
    await outFile.writeAsBytes(await pdfDoc.save());
    return outFile;
  }

  static int _slideNumber(String path) {
    final match = RegExp(r'slide(\d+)\.xml$').firstMatch(path);
    return int.parse(match!.group(1)!);
  }
}