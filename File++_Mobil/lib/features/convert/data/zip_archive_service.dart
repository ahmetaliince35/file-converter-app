import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../../core/files/temp_file_manager.dart';
import 'universal_converter_service.dart';

class ZipEntryItem {
  final String path;
  final String name;
  final String extension;
  final int uncompressedSize;
  final bool isConvertible;

  const ZipEntryItem({
    required this.path,
    required this.name,
    required this.extension,
    required this.uncompressedSize,
    required this.isConvertible,
  });

  String get formattedSize {
    if (uncompressedSize <= 0) return '0 B';
    if (uncompressedSize < 1024) return '$uncompressedSize B';
    if (uncompressedSize < 1024 * 1024) {
      return '${(uncompressedSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(uncompressedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// ZIP dosyalarını belleği tüketmeden güvenle inceleyen ve sadece seçilen dosyaları çıkaran servis.
class ZipArchiveService {
  const ZipArchiveService();

  /// Metne veya PDF'e dönüştürülebilir dosya uzantıları (Ses, video ve resimler hariçtir)
  static Set<String> get convertibleExtensions => {
        // Belgeler
        'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'pdf',
        // Düz Metin & Veri
        'txt', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml', 'md', 'markdown', 'rtf', 'log', 'ini', 'env',
        // Tüm Kaynak Kod Dosyaları
        ...UniversalConverterService.codeExtensions,
      };

  /// ZIP dosyasını açıp içindeki dönüştürülebilir dosyaların listesini döner (Crash ve bellek patlamasını önler)
  Future<List<ZipEntryItem>> inspectZip(File zipFile) async {
    if (!await zipFile.exists()) {
      throw const FileSystemException('ZIP arşivi bulunamadı');
    }

    try {
      final entries = await compute(_inspectWorker, zipFile.path);
      return entries;
    } catch (e) {
      debugPrint('[ZIP_INSPECT_ERROR] $e');
      throw Exception('ZIP dosyası açılamadı veya bozuk: $e');
    }
  }

  /// Sadece kullanıcının seçtiği dosya yollarını disk üzerindeki geçici klasöre ayıklar
  Future<List<File>> extractSelectedFiles({
    required File zipFile,
    required List<String> selectedPaths,
  }) async {
    if (selectedPaths.isEmpty) return [];

    final workingDir = await TempFileManager.workingDir;
    final targetDirPath = p.join(
      workingDir.path,
      'zip_extracted_${DateTime.now().millisecondsSinceEpoch}',
    );

    try {
      final extractedPaths = await compute(_extractSelectedWorker, {
        'zipPath': zipFile.path,
        'targetDir': targetDirPath,
        'selectedPaths': selectedPaths,
      });

      return extractedPaths.map((p) => File(p)).toList();
    } catch (e) {
      debugPrint('[ZIP_EXTRACT_SELECTED_ERROR] $e');
      throw Exception('Seçilen dosyalar arşivden çıkartılamadı: $e');
    }
  }
}

/// Arka plan izolesi: Sadece başlıkları ve dosya listesini okur, dosyaların içeriğini RAM'e yüklemez
List<ZipEntryItem> _inspectWorker(String zipPath) {
  Archive archive;
  InputFileStream? inputStream;
  try {
    inputStream = InputFileStream(zipPath);
    archive = ZipDecoder().decodeBuffer(inputStream, verify: false);
  } catch (_) {
    final file = File(zipPath);
    final bytes = file.readAsBytesSync();
    archive = ZipDecoder().decodeBytes(bytes, verify: false);
  }

  final items = <ZipEntryItem>[];

  for (final fileEntry in archive) {
    if (!fileEntry.isFile) continue;

    final rawPath = fileEntry.name.replaceAll('\\', '/');
    if (rawPath.startsWith('__MACOSX') || p.basename(rawPath).startsWith('._')) {
      continue;
    }

    final ext = p.extension(rawPath).replaceAll('.', '').toLowerCase();
    final isConvertible = ZipArchiveService.convertibleExtensions.contains(ext);

    items.add(
      ZipEntryItem(
        path: rawPath,
        name: p.basename(rawPath),
        extension: ext,
        uncompressedSize: fileEntry.size,
        isConvertible: isConvertible,
      ),
    );
  }

  archive.clear();
  try {
    inputStream?.close();
  } catch (_) {}
  return items;
}

/// Arka plan izolesi: Sadece seçili dosyaları diske yazar
List<String> _extractSelectedWorker(Map<String, dynamic> args) {
  final zipPath = args['zipPath'] as String;
  final targetDir = args['targetDir'] as String;
  final selectedPaths = Set<String>.from(args['selectedPaths'] as List);

  Archive archive;
  InputFileStream? inputStream;
  try {
    inputStream = InputFileStream(zipPath);
    archive = ZipDecoder().decodeBuffer(inputStream, verify: false);
  } catch (_) {
    final file = File(zipPath);
    final bytes = file.readAsBytesSync();
    archive = ZipDecoder().decodeBytes(bytes, verify: false);
  }

  final outPaths = <String>[];
  final rootDir = Directory(targetDir);
  if (!rootDir.existsSync()) {
    rootDir.createSync(recursive: true);
  }

  for (final fileEntry in archive) {
    if (!fileEntry.isFile) continue;
    final rawPath = fileEntry.name.replaceAll('\\', '/');

    if (selectedPaths.contains(rawPath)) {
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(rawPath)}';
      final outFile = File(p.join(targetDir, safeName));

      final dynamic rawContent = fileEntry.content;
      if (rawContent != null) {
        outFile.writeAsBytesSync(rawContent as List<int>, flush: true);
        outPaths.add(outFile.path);
      }
    }
  }

  archive.clear();
  try {
    inputStream?.close();
  } catch (_) {}
  return outPaths;
}
