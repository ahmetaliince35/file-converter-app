import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:xml/xml.dart';

import 'package:dosya_converter/core/files/temp_file_manager.dart';
import 'package:dosya_converter/features/auth/data/google_auth_service.dart';
import 'package:dosya_converter/features/auth/data/microsoft_auth_service.dart';
import 'package:dosya_converter/features/cloud/data/office_to_pdf_service.dart';

enum UniversalTargetFormat {
  pdf,
  txt,
}

enum FileFormatCategory {
  pdf,
  officeDoc,
  officeExcel,
  officePpt,
  textOrCode,
  zip,
  unknown,
}

/// Sadece dönüştürülebilir metin, kod, tablo ve belgeleri TXT ve PDF formatlarına dönüştüren bellek optimizasyonlu merkezi servis.
/// Not: Ses, video ve resim dosyaları bu dönüştürücü kapsamı dışındadır.
class UniversalConverterService {
  final OfficeToPdfService _officeToPdf;

  const UniversalConverterService({
    OfficeToPdfService officeToPdf = const OfficeToPdfService(),
  }) : _officeToPdf = officeToPdf;

  /// Kaynak Kod ve Betik Uzantıları (150+ Programlama Dili ve Format)
  static const Set<String> codeExtensions = {
    // Dart & Flutter
    'dart',
    // Web / JS / TS / Modern Frameworks
    'js', 'mjs', 'cjs', 'jsx', 'ts', 'mts', 'cts', 'tsx', 'vue', 'svelte', 'astro',
    'html', 'htm', 'xhtml', 'css', 'scss', 'sass', 'less',
    // Python & Veri Bilimi
    'py', 'pyw', 'pyi', 'pyx', 'r', 'rmd', 'jl', 'ipynb',
    // Sistem & Yerel Diller
    'c', 'h', 'cpp', 'hpp', 'cc', 'hh', 'cxx', 'hxx', 'ino',
    'cs', 'csx', 'rs', 'go', 'zig', 'nim', 'd', 'v', 'odin', 'pas', 'pp', 'asm', 's',
    'swift', 'm', 'mm',
    // JVM Dilleri
    'java', 'kt', 'kts', 'scala', 'sc', 'groovy', 'gvy', 'gradle', 'clj', 'cljs',
    // Kabuk & Betik Dilleri
    'sh', 'bash', 'zsh', 'fish', 'ksh', 'ps1', 'psm1', 'bat', 'cmd',
    'lua', 'rb', 'rbw', 'rake', 'php', 'phtml', 'pl', 'pm', 'tcl', 'awk', 'sed',
    // Yapılandırılmış Veri & Konfigürasyon
    'json', 'jsonc', 'json5', 'yaml', 'yml', 'toml', 'xml', 'svg', 'csv', 'tsv',
    'ini', 'conf', 'config', 'cfg', 'properties', 'env', 'dotenv', 'lock',
    'mod', 'sum',
    // Veritabanı & Sorgu Dilleri
    'sql', 'mysql', 'pgsql', 'sqlite', 'prisma', 'graphql', 'gql',
    // DevOps & Konteyner
    'dockerfile', 'containerfile', 'makefile', 'cmake', 'vagrantfile', 'jenkinsfile',
    // Dokümantasyon & Notlar
    'md', 'markdown', 'mdx', 'rst', 'tex', 'latex', 'log', 'txt', 'rtf',
    // Shader & Grafikler
    'glsl', 'hlsl', 'frag', 'vert', 'shader',
    // Fonksiyonel & Diğerleri
    'hs', 'lhs', 'elm', 'erl', 'hrl', 'ex', 'exs', 'fs', 'fsi', 'fsx', 'ml', 'mli',
  };

  /// Kesinlikle dönüştürülmeyecek medya dosyaları (Ses, video, resim)
  static const Set<String> blockedMediaExtensions = {
    // Ses
    'mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg', 'wma', 'opus', 'aiff', 'alac',
    // Video
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'm4v', 'mpeg', 'mpg',
    // Resim
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'heic', 'heif', 'ico', 'raw',
  };

  /// Yürütülebilir veya doğrudan metin içermeyen ikili sistem dosyaları
  static const Set<String> blockedBinaryExtensions = {
    'exe', 'dll', 'so', 'dylib', 'bin', 'apk', 'aab', 'ipa', 'iso', 'img', 'dmg', 'sys',
  };

  /// Desteklenen dönüştürülebilir dosya uzantıları listesi (Ses, video, resim içermez)
  static List<String> get supportedExtensions => [
        // Belgeler
        'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'pdf',
        // Kod ve metin dosyaları
        ...codeExtensions,
        // Arşiv
        'zip',
      ];

  /// Uzantının kod veya metin tabanlı olup olmadığını döndürür
  static bool isTextOrCodeExtension(String ext) {
    final lower = ext.toLowerCase().replaceFirst('.', '');
    return codeExtensions.contains(lower) ||
        ['txt', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml', 'md', 'markdown', 'log', 'ini', 'env', 'rtf'].contains(lower);
  }

  /// Dosyanın format kategorisini tespit eder
  static FileFormatCategory detectCategory(File file) {
    final ext = _getExtension(file);
    if (blockedMediaExtensions.contains(ext) || blockedBinaryExtensions.contains(ext)) {
      return FileFormatCategory.unknown;
    }

    switch (ext) {
      case 'pdf':
        return FileFormatCategory.pdf;
      case 'docx':
      case 'doc':
        return FileFormatCategory.officeDoc;
      case 'xlsx':
      case 'xls':
        return FileFormatCategory.officeExcel;
      case 'pptx':
      case 'ppt':
        return FileFormatCategory.officePpt;
      case 'zip':
        return FileFormatCategory.zip;
      default:
        // Ses/video/ikili olmayan tüm kaynak kodları, betikleri ve metinleri kapsar
        return FileFormatCategory.textOrCode;
    }
  }

  /// Verilen dosyayı belirtilen hedef formata (PDF veya TXT) dönüştürür
  Future<File> convert({
    required File file,
    required UniversalTargetFormat target,
    void Function(double progress, String status)? onProgress,
    GoogleAuthService? googleAuth,
    MicrosoftAuthService? microsoftAuth,
  }) async {
    final category = detectCategory(file);

    if (category == FileFormatCategory.unknown) {
      throw Exception(
        'Desteklenmeyen dosya türü. Ses, video ve resim dosyaları bu araçla dönüştürülemez.',
      );
    }

    if (target == UniversalTargetFormat.txt) {
      return _convertToTxt(file, category, onProgress: onProgress);
    } else {
      return _convertToPdf(
        file,
        category,
        onProgress: onProgress,
        googleAuth: googleAuth,
        microsoftAuth: microsoftAuth,
      );
    }
  }

  // ===========================================================================
  // TXT DÖNÜŞTÜRÜCÜ METOTLARI
  // ===========================================================================

  Future<File> _convertToTxt(
    File file,
    FileFormatCategory category, {
    void Function(double, String)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Dosya okunuyor ve metin ayıklanıyor...');
    String extractedText = '';

    switch (category) {
      case FileFormatCategory.textOrCode:
        extractedText = await _readTextOrCodeFile(file);
        break;

      case FileFormatCategory.pdf:
        onProgress?.call(0.3, 'PDF sayfalarından metin ayıklanıyor...');
        extractedText = await _extractTextFromPdf(file);
        break;

      case FileFormatCategory.officeDoc:
        onProgress?.call(0.3, 'Word belgesinden paragraflar ayıklanıyor...');
        extractedText = await _extractTextFromDocx(file);
        break;

      case FileFormatCategory.officeExcel:
        onProgress?.call(0.3, 'Excel tabloları ve hücreler taranıyor...');
        extractedText = await _extractTextFromExcel(file);
        break;

      case FileFormatCategory.officePpt:
        onProgress?.call(0.3, 'PowerPoint slayt metinleri ayıklanıyor...');
        extractedText = await _extractTextFromPptx(file);
        break;

      case FileFormatCategory.zip:
        throw Exception('ZIP dosyaları doğrudan metne dönüştürülemez. Lütfen içindeki belgeleri seçin.');

      case FileFormatCategory.unknown:
        extractedText = await _readTextOrCodeFile(file);
        break;
    }

    if (extractedText.trim().isEmpty) {
      extractedText = '[Bu dosyadan okunabilir metin içeriği ayıklanamadı veya dosya boş.]';
    }

    onProgress?.call(0.9, 'TXT dosyası kaydediliyor...');
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(file.path);
    final outPath = p.join(
      workingDir.path,
      '${baseName}_metin_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    final outFile = File(outPath);
    await outFile.writeAsString(extractedText, flush: true);
    onProgress?.call(1.0, 'Tamamlandı!');

    return outFile;
  }

  // ===========================================================================
  // PDF DÖNÜŞTÜRÜCÜ METOTLARI
  // ===========================================================================

  Future<File> _convertToPdf(
    File file,
    FileFormatCategory category, {
    void Function(double, String)? onProgress,
    GoogleAuthService? googleAuth,
    MicrosoftAuthService? microsoftAuth,
  }) async {
    // 1. Zaten PDF ise
    if (category == FileFormatCategory.pdf) {
      return file;
    }

    // 2. Office formatı (DOCX, PPTX, XLSX) ise ve bulut hesabı varsa bulutta çevir
    if ((category == FileFormatCategory.officeDoc ||
            category == FileFormatCategory.officeExcel ||
            category == FileFormatCategory.officePpt) &&
        googleAuth != null &&
        microsoftAuth != null &&
        (googleAuth.isSignedIn || microsoftAuth.isSignedIn)) {
      onProgress?.call(0.2, 'Bulut motoru ile yüksek çözünürlüklü PDF yapılıyor...');
      try {
        final pdf = await _officeToPdf.convert(
          file,
          googleAuth: googleAuth,
          microsoftAuth: microsoftAuth,
        );
        return pdf;
      } catch (e) {
        debugPrint('Bulut dönüşüm hatası, yerel ayrıştırmaya geçiliyor: $e');
      }
    }

    // 3. Metin, kod veya yerel fallback: Önce metni çıkar ardından şık bir A4 PDF oluştur
    onProgress?.call(0.2, 'Dosya içeriği okunuyor...');
    final text = await _extractContentAsText(file, category);

    onProgress?.call(0.6, 'A4 PDF sayfalandırması ve tipografi hazırlanıyor...');
    final baseName = p.basename(file.path);
    final ext = _getExtension(file);
    final isCode = codeExtensions.contains(ext);
    return _generateStyledPdfFromText(
      title: baseName,
      content: text,
      isCode: isCode,
      onProgress: onProgress,
    );
  }

  // ===========================================================================
  // ÖZEL AYIKLAYICILAR (EXTRACTORS - CRASH & BELLEK GÜVENLİKLİ)
  // ===========================================================================

  static Future<String> _readTextOrCodeFile(File file) async {
    try {
      final size = await file.length();
      // 30 MB üzeri devasa metin dosyalarında bellek patlamasını önle
      if (size > 30 * 1024 * 1024) {
        final stream = file.openRead(0, 15 * 1024 * 1024);
        final bytes = await stream.expand((b) => b).toList();
        return '${decodeTextBytes(bytes)}\n\n... [Dosya 30 MB üzerinde olduğu için performans güvenliği adına ilk 15 MB metne dönüştürülmüştür] ...';
      }

      final bytes = await file.readAsBytes();
      return decodeTextBytes(bytes);
    } catch (e) {
      return 'Dosya okunamadı: $e';
    }
  }

  /// UTF-8 (BOM'lu/BOM'suz), UTF-16LE, UTF-16BE ve Latin-1/Windows-1254 uyumlu çok aşamalı kayıpsız metin çözümleyici.
  static String decodeTextBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // 1. UTF-8 BOM kontrolü (0xEF, 0xBB, 0xBF)
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      try {
        return utf8.decode(bytes.sublist(3));
      } catch (_) {}
    }

    // 2. UTF-16 LE BOM kontrolü (0xFF, 0xFE)
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      try {
        final buffer = StringBuffer();
        for (int i = 2; i < bytes.length - 1; i += 2) {
          final codeUnit = bytes[i] | (bytes[i + 1] << 8);
          buffer.writeCharCode(codeUnit);
        }
        return buffer.toString();
      } catch (_) {}
    }

    // 3. UTF-16 BE BOM kontrolü (0xFE, 0xFF)
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      try {
        final buffer = StringBuffer();
        for (int i = 2; i < bytes.length - 1; i += 2) {
          final codeUnit = (bytes[i] << 8) | bytes[i + 1];
          buffer.writeCharCode(codeUnit);
        }
        return buffer.toString();
      } catch (_) {}
    }

    // 4. Standart UTF-8 çözümleme
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {}

    // 5. UTF-8 toleranslı veya Latin-1 çözümleme (asla çökmez)
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static Future<String> _extractTextFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final document = sf_pdf.PdfDocument(inputBytes: bytes);
      final textExtractor = sf_pdf.PdfTextExtractor(document);
      final text = textExtractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('PDF metin çıkarma hatası: $e');
      return 'PDF metni okunamadı: $e';
    }
  }

  static Future<String> _extractTextFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');

      if (docFile == null) return 'Word belgesi içeriği bulunamadı.';

      final xmlString = utf8.decode(docFile.content as List<int>);
      final document = XmlDocument.parse(xmlString);

      final buffer = StringBuffer();
      final paragraphs = document.findAllElements('w:p');

      int pCount = 0;
      for (final p in paragraphs) {
        final texts = p.findAllElements('w:t').map((e) => e.innerText).join();
        if (texts.trim().isNotEmpty) {
          buffer.writeln(texts);
          pCount++;
          if (pCount > 20000) {
            buffer.writeln('\n... [Çok büyük Word belgesi: İlk 20.000 paragraf ayıklandı] ...');
            break;
          }
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      return 'DOCX metni ayıklanamadı: $e';
    }
  }

  static Future<String> _extractTextFromExcel(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = ex.Excel.decodeBytes(bytes);
      final buffer = StringBuffer();

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        buffer.writeln('=== SAYFA: $table ===');

        int rowCount = 0;
        for (final row in sheet.rows) {
          final rowString = row
              .map((cell) => cell?.value?.toString().trim() ?? '')
              .join(' | ');
          if (rowString.replaceAll('|', '').trim().isNotEmpty) {
            buffer.writeln(rowString);
            rowCount++;
            // 5000 satırdan büyük sayfalarda bellek patlamasını önle
            if (rowCount > 5000) {
              buffer.writeln('... [Sayfada 5.000\'den fazla satır var. Performans için ilk 5.000 satır alındı] ...');
              break;
            }
          }
        }
        buffer.writeln();
      }

      return buffer.toString().trim();
    } catch (e) {
      return 'Excel verisi okunamadı: $e';
    }
  }

  static Future<String> _extractTextFromPptx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final buffer = StringBuffer();

      int slideIndex = 1;
      while (slideIndex <= 300) {
        final slideFile = archive.findFile('ppt/slides/slide$slideIndex.xml');
        if (slideFile == null) break;

        final xmlString = utf8.decode(slideFile.content as List<int>);
        final document = XmlDocument.parse(xmlString);

        buffer.writeln('=== SLAYT $slideIndex ===');
        final texts = document.findAllElements('a:t').map((e) => e.innerText);
        for (final text in texts) {
          if (text.trim().isNotEmpty) {
            buffer.writeln(text);
          }
        }
        buffer.writeln();
        slideIndex++;
      }

      return buffer.toString().trim();
    } catch (e) {
      return 'PowerPoint metinleri okunamadı: $e';
    }
  }

  Future<String> _extractContentAsText(File file, FileFormatCategory category) async {
    switch (category) {
      case FileFormatCategory.textOrCode:
        return _readTextOrCodeFile(file);
      case FileFormatCategory.pdf:
        return _extractTextFromPdf(file);
      case FileFormatCategory.officeDoc:
        return _extractTextFromDocx(file);
      case FileFormatCategory.officeExcel:
        return _extractTextFromExcel(file);
      case FileFormatCategory.officePpt:
        return _extractTextFromPptx(file);
      case FileFormatCategory.zip:
        throw Exception('ZIP arşivleri doğrudan PDF\'e dönüştürülemez. Lütfen içindeki dönüştürmek istediğiniz belgeleri seçin.');
      case FileFormatCategory.unknown:
        return _readTextOrCodeFile(file);
    }
  }

  /// Bellek korumalı ve parçalı MultiPage A4 PDF motoru (Crash ve TooManyPagesException önler)
  static Future<File> _generateStyledPdfFromText({
    required String title,
    required String content,
    bool isCode = false,
    void Function(double, String)? onProgress,
  }) async {
    final pdf = pw.Document();

    pw.Font fontRegular;
    pw.Font fontBold;

    if (isCode) {
      try {
        fontRegular = await PdfGoogleFonts.robotoMonoRegular();
        fontBold = await PdfGoogleFonts.robotoMonoBold();
      } catch (_) {
        fontRegular = pw.Font.courier();
        fontBold = pw.Font.courierBold();
      }
    } else {
      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (_) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }
    }

    final rawLines = content.split('\n');
    final totalLines = rawLines.length;

    // Çok büyük metinlerde (10.000 satırdan fazla) bellek taşmasını önle
    final linesToProcess = totalLines > 10000 ? rawLines.sublist(0, 10000) : rawLines;
    final isTruncated = totalLines > 10000;

    // Tek bir devasa String yerine satırları 60'arlı paragraflar halinde gruplayarak layout motorunu koru
    final contentWidgets = <pw.Widget>[];

    contentWidgets.add(
      pw.Header(
        level: 0,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            if (isCode)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
                ),
                child: pw.Text(
                  'KAYNAK KODU',
                  style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.blueGrey800),
                ),
              ),
          ],
        ),
      ),
    );
    contentWidgets.add(pw.SizedBox(height: 6));

    const int chunkSize = 60;
    for (int i = 0; i < linesToProcess.length; i += chunkSize) {
      final end = (i + chunkSize < linesToProcess.length) ? i + chunkSize : linesToProcess.length;
      final chunkBuffer = StringBuffer();

      for (int lineIdx = i; lineIdx < end; lineIdx++) {
        final lineStr = linesToProcess[lineIdx].replaceAll('\r', '');
        if (isCode) {
          final lineNum = '${lineIdx + 1}'.padLeft(4, ' ');
          chunkBuffer.writeln('$lineNum | $lineStr');
        } else {
          chunkBuffer.writeln(lineStr);
        }
      }

      contentWidgets.add(
        pw.Paragraph(
          text: chunkBuffer.toString().trimRight(),
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: isCode ? 7.5 : 9.5,
            lineSpacing: isCode ? 1.4 : 2.4,
            color: PdfColors.grey900,
          ),
        ),
      );
    }

    if (isTruncated) {
      contentWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
          ),
          child: pw.Text(
            '[Bu dosya çok büyük olduğu için performans ve bellek güvenliği adına ilk 10.000 satır derlenmiştir. Kalan $totalLines satır için dosya bölme araçlarını kullanabilirsiniz.]',
            style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.amber900),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 2000, // Varsayılan 100 limitini 2000'e çıkararak TooManyPagesException crash'ini engeller
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  isCode ? 'File++ Kaynak Kodu' : 'File++ Belge Stüdyosu',
                  style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Sayfa ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500),
            ),
          );
        },
        build: (pw.Context context) => contentWidgets,
      ),
    );

    onProgress?.call(0.95, 'PDF dosyası kaydediliyor...');
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(title);
    final outPath = p.join(
      workingDir.path,
      '${baseName}_belge_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());
    onProgress?.call(1.0, 'Dönüşüm tamamlandı!');

    return outFile;
  }

  static String _getExtension(File file) {
    final name = p.basename(file.path);
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return '';
  }
}
