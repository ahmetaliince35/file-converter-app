import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    onProgress?.call(0.1, 'Dosya hazırlanıyor...');
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(file.path);
    final outPath = p.join(
      workingDir.path,
      '${baseName}_metin_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    final outFile = File(outPath);

    // Eğer kaynak zaten metin/kod ise, tüm dosyayı belleğe string olarak alıp şişirmek yerine
    // doğrudan stream chunk'ları ile adım adım aktar ve anlık MB/yüzde bilgisini progress bar'a yansıt
    if (category == FileFormatCategory.textOrCode) {
      final totalBytes = await file.length();
      int processedBytes = 0;
      final reader = file.openRead();
      final sink = outFile.openWrite();
      int lastReportedPct = -1;
      final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

      onProgress?.call(0.05, 'Adım adım belleğe aktarılıyor: 0.0 MB / $mbTotal MB (%0)...');

      await for (final chunk in reader) {
        sink.add(chunk);
        processedBytes += chunk.length;

        final ratio = totalBytes > 0 ? (processedBytes / totalBytes).clamp(0.0, 1.0) : 0.5;
        final pct = (ratio * 100).toInt();

        if (pct != lastReportedPct) {
          lastReportedPct = pct;
          final mbRead = (processedBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress?.call(
            ratio,
            'Adım adım belleğe aktarılıyor: $mbRead MB / $mbTotal MB (%$pct)',
          );
        }
      }

      onProgress?.call(0.98, 'Diske yazılıyor ve tamamlanıyor...');
      await sink.flush();
      await sink.close();
      onProgress?.call(1.0, 'Dönüşüm tamamlandı! (%100)');
      return outFile;
    }

    onProgress?.call(0.2, 'İçerik taranıyor ve metin ayıklanıyor...');
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

    // 3. Metin veya kaynak kod dosyaları: Doğrudan akış (stream) ile satır satır okuyup
    // sıfır bellek tüketimiyle hızlı A4 sayfalandırma uygula (4-5 dakikalık layout donmasını ve çöküşü önler)
    if (category == FileFormatCategory.textOrCode) {
      final baseName = p.basename(file.path);
      final ext = _getExtension(file);
      final isCode = codeExtensions.contains(ext);
      return _generatePdfFromTextOrCodeStream(
        file: file,
        title: baseName,
        isCode: isCode,
        onProgress: onProgress,
      );
    }

    // 4. Diğer belgeler (Office yerel fallback veya PDF metinleri)
    onProgress?.call(0.2, 'Dosya içeriği okunuyor...');
    final text = await _extractContentAsText(file, category);

    onProgress?.call(0.5, 'A4 PDF sayfalandırması ve tipografi hazırlanıyor...');
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
      // 3 MB üzeri büyük metin dosyalarında bellek patlamasını önle (3 MB ~60.000 satırdır)
      if (size > 3 * 1024 * 1024) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(0, 3 * 1024 * 1024)) {
          builder.add(chunk);
        }
        return '${decodeTextBytes(builder.takeBytes())}\n\n... [Dosya boyutu çok büyük olduğu için mobil bellek güvenliği adına ilk 3 MB metne dönüştürülmüştür] ...';
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
      return await compute(_extractPdfWorker, file.path);
    } catch (e) {
      debugPrint('PDF metin çıkarma hatası: $e');
      return 'PDF metni okunamadı: $e';
    }
  }

  static Future<String> _extractTextFromDocx(File file) async {
    try {
      return await compute(_extractDocxWorker, file.path);
    } catch (e) {
      return 'DOCX metni ayıklanamadı: $e';
    }
  }

  static Future<String> _extractTextFromExcel(File file) async {
    try {
      return await compute(_extractExcelWorker, file.path);
    } catch (e) {
      return 'Excel verisi okunamadı: $e';
    }
  }

  static Future<String> _extractTextFromPptx(File file) async {
    try {
      return await compute(_extractPptxWorker, file.path);
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

  /// Büyük metin ve kaynak kod dosyalarını satır satır akışla okuyup
  /// sıfır bellek tüketimi ve anlık ilerleme bildirimiyle A4 PDF'e dönüştürür.
  static Future<File> _generatePdfFromTextOrCodeStream({
    required File file,
    required String title,
    bool isCode = false,
    void Function(double, String)? onProgress,
  }) async {
    final pdf = pw.Document();
    final fileSize = await file.length();
    final fileSizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);

    onProgress?.call(0.05, 'Yazı tipi ve sayfa yapısı hazırlanıyor...');

    pw.Font fontRegular;
    pw.Font fontBold;

    if (isCode) {
      try {
        fontRegular = await PdfGoogleFonts.robotoMonoRegular().timeout(const Duration(seconds: 2));
        fontBold = await PdfGoogleFonts.robotoMonoBold().timeout(const Duration(seconds: 2));
      } catch (_) {
        fontRegular = pw.Font.courier();
        fontBold = pw.Font.courierBold();
      }
    } else {
      try {
        fontRegular = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 2));
        fontBold = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 2));
      } catch (_) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }
    }

    onProgress?.call(0.1, 'Satırlar adım adım taranıyor ($fileSizeMb MB)...');

    const int linesPerPage = 42;
    const int maxPages = 40; // Mobil cihaz bellek güvenliği için 40 sayfa (~1.680 satır)

    final pageLinesList = <List<String>>[];
    var currentBatch = <String>[];
    int totalLinesRead = 0;
    bool isTruncated = false;

    final lineStream = file
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    try {
      await for (final line in lineStream) {
        totalLinesRead++;
        final cleanLine = line.replaceAll('\r', '');
        if (isCode) {
          final lineNum = '$totalLinesRead'.padLeft(4, ' ');
          currentBatch.add('$lineNum | $cleanLine');
        } else {
          currentBatch.add(cleanLine);
        }

        if (currentBatch.length >= linesPerPage) {
          pageLinesList.add(List.unmodifiable(currentBatch));
          currentBatch = <String>[];
          final currentPages = pageLinesList.length;
          onProgress?.call(
            0.1 + (0.3 * (currentPages / maxPages).clamp(0.0, 1.0)),
            'Sayfalar taranıyor: $currentPages sayfa ($totalLinesRead satır)...',
          );
          if (pageLinesList.length >= maxPages) {
            isTruncated = true;
            break;
          }
        }
      }
      if (currentBatch.isNotEmpty && pageLinesList.length < maxPages) {
        pageLinesList.add(currentBatch);
      }
    } catch (e) {
      debugPrint('Akış okuma uyarısı: $e');
    }

    final totalPages = pageLinesList.isEmpty ? 1 : pageLinesList.length;

    for (int pIdx = 0; pIdx < pageLinesList.length; pIdx++) {
      final pageNum = pIdx + 1;
      final lines = pageLinesList[pIdx];
      final isLastPage = pageNum == totalPages;

      onProgress?.call(
        0.4 + (0.5 * (pageNum / totalPages)),
        'PDF Sayfası Hazırlanıyor: $pageNum / $totalPages (%${((pageNum / totalPages) * 100).toInt()})...',
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blueGrey800),
                      ),
                      pw.Text(
                        isCode ? 'File++ Kaynak Kodu' : 'File++ Belge Stüdyosu',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Text(
                    lines.join('\n'),
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: isCode ? 7.2 : 9.0,
                      lineSpacing: isCode ? 1.3 : 1.7,
                      color: PdfColors.grey900,
                    ),
                  ),
                ),
                if (isLastPage && isTruncated) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
                    ),
                    child: pw.Text(
                      '[Bu büyük dosya ($fileSizeMb MB) için ilk $totalLinesRead satır ($totalPages sayfa) PDF olarak derlenmiştir. Dosyanın tamamına TXT formatına dönüştürerek erişebilirsiniz.]',
                      style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.amber900),
                    ),
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'File++',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey400),
                      ),
                      pw.Text(
                        'Sayfa $pageNum / $totalPages',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    onProgress?.call(0.95, 'PDF diske kaydediliyor...');
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(title);
    final outPath = p.join(
      workingDir.path,
      '${baseName}_belge_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());
    onProgress?.call(1.0, 'Dönüşüm tamamlandı! (%100)');

    return outFile;
  }

  /// Metin içeriğini hızlı ve bellek korumalı bağımsız A4 sayfaları halinde derleyen PDF motoru
  static Future<File> _generateStyledPdfFromText({
    required String title,
    required String content,
    bool isCode = false,
    void Function(double, String)? onProgress,
  }) async {
    final pdf = pw.Document();

    onProgress?.call(0.1, 'Tipografi hazırlanıyor...');

    pw.Font fontRegular;
    pw.Font fontBold;

    if (isCode) {
      try {
        fontRegular = await PdfGoogleFonts.robotoMonoRegular().timeout(const Duration(seconds: 2));
        fontBold = await PdfGoogleFonts.robotoMonoBold().timeout(const Duration(seconds: 2));
      } catch (_) {
        fontRegular = pw.Font.courier();
        fontBold = pw.Font.courierBold();
      }
    } else {
      try {
        fontRegular = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 2));
        fontBold = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 2));
      } catch (_) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
      }
    }

    final rawLines = content.split('\n');
    const int linesPerPage = 42;
    const int maxPages = 40;
    const int maxSafeLines = linesPerPage * maxPages;

    final linesToProcess = rawLines.length > maxSafeLines
        ? rawLines.sublist(0, maxSafeLines)
        : rawLines;
    final isTruncated = rawLines.length > maxSafeLines;

    final pageLinesList = <List<String>>[];
    for (int i = 0; i < linesToProcess.length; i += linesPerPage) {
      final end = (i + linesPerPage < linesToProcess.length) ? i + linesPerPage : linesToProcess.length;
      final pageBatch = <String>[];
      for (int lineIdx = i; lineIdx < end; lineIdx++) {
        final lineStr = linesToProcess[lineIdx].replaceAll('\r', '');
        if (isCode) {
          final lineNum = '${lineIdx + 1}'.padLeft(4, ' ');
          pageBatch.add('$lineNum | $lineStr');
        } else {
          pageBatch.add(lineStr);
        }
      }
      pageLinesList.add(pageBatch);
    }

    final totalPages = pageLinesList.isEmpty ? 1 : pageLinesList.length;

    for (int pIdx = 0; pIdx < pageLinesList.length; pIdx++) {
      final pageNum = pIdx + 1;
      final lines = pageLinesList[pIdx];
      final isLastPage = pageNum == totalPages;

      onProgress?.call(
        0.3 + (0.6 * (pageNum / totalPages)),
        'Sayfa $pageNum / $totalPages hazırlanıyor...',
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blueGrey800),
                      ),
                      pw.Text(
                        isCode ? 'File++ Kaynak Kodu' : 'File++ Belge Stüdyosu',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Text(
                    lines.join('\n'),
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: isCode ? 7.2 : 9.0,
                      lineSpacing: isCode ? 1.3 : 1.7,
                      color: PdfColors.grey900,
                    ),
                  ),
                ),
                if (isLastPage && isTruncated) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
                    ),
                    child: pw.Text(
                      '[Mobil bellek güvenliği için ilk $maxSafeLines satır ($totalPages sayfa) PDF olarak derlenmiştir. Dosyanın tamamına TXT formatına dönüştürerek erişebilirsiniz.]',
                      style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.amber900),
                    ),
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'File++',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey400),
                      ),
                      pw.Text(
                        'Sayfa $pageNum / $totalPages',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    onProgress?.call(0.95, 'PDF diske kaydediliyor...');
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(title);
    final outPath = p.join(
      workingDir.path,
      '${baseName}_belge_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());
    onProgress?.call(1.0, 'Dönüşüm tamamlandı! (%100)');

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

// ===========================================================================
// İZOLE ARKA PLAN İŞÇİLERİ (ISOLATE WORKERS - BELLEĞİ SERBEST BIRAKIR)
// ===========================================================================

String _extractPdfWorker(String filePath) {
  sf_pdf.PdfDocument? document;
  try {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    document = sf_pdf.PdfDocument(inputBytes: bytes);
    final totalPages = document.pages.count;
    if (totalPages == 0) return '[PDF belgesinde sayfa bulunamadı]';

    final pagesToExtract = totalPages > 100 ? 100 : totalPages;
    final textExtractor = sf_pdf.PdfTextExtractor(document);
    final text = textExtractor.extractText(startPageIndex: 0, endPageIndex: pagesToExtract - 1);

    if (totalPages > 100) {
      return '$text\n\n... [Performans ve bellek güvenliği adına $totalPages sayfanın ilk 100 sayfası ayıklandı] ...';
    }
    return text;
  } catch (e) {
    return 'PDF metni okunamadı: $e';
  } finally {
    try {
      document?.dispose();
    } catch (_) {}
  }
}

String _extractDocxWorker(String filePath) {
  try {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
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
        if (pCount > 3000) {
          buffer.writeln('\n... [Büyük Word belgesi: Performans ve bellek güvenliği için ilk 3.000 paragraf ayıklandı] ...');
          break;
        }
      }
    }

    return buffer.toString().trim();
  } catch (e) {
    return 'DOCX metni ayıklanamadı: $e';
  }
}

String _extractExcelWorker(String filePath) {
  try {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final excel = ex.Excel.decodeBytes(bytes);
    final buffer = StringBuffer();

    int sheetCount = 0;
    for (final table in excel.tables.keys) {
      if (sheetCount >= 10) {
        buffer.writeln('... [İlk 10 çalışma sayfası ayıklandı] ...');
        break;
      }
      sheetCount++;

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
          if (rowCount > 1500) {
            buffer.writeln('... [Bu sayfada 1.500\'den fazla satır var. Performans için ilk 1.500 satır alındı] ...');
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

String _extractPptxWorker(String filePath) {
  try {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final buffer = StringBuffer();

    int slideIndex = 1;
    while (slideIndex <= 100) {
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

    if (slideIndex > 100) {
      buffer.writeln('... [İlk 100 slayt ayıklandı] ...');
    }

    return buffer.toString().trim();
  } catch (e) {
    return 'PowerPoint metinleri okunamadı: $e';
  }
}
