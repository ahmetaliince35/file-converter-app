import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TempFileManager {
  static const String _folderName = 'converter_cache';

  /// Sadece uygulamaya özel çalışma klasörü
  static Future<Directory> get workingDir async {
    final baseDir = await getTemporaryDirectory();
    final dir = Directory('${baseDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Tek bir dosyayı güvenle siler
  static Future<void> deleteFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Dosya silinirken hata: $e');
    }
  }

  /// Dosya listesini güvenle siler
  static Future<void> deleteFiles(List<File> files) async {
    for (final f in files) {
      await deleteFile(f);
    }
  }

  /// Kök cache dahil tüm geçici dosyaları (ImagePicker artıkları, eski çıktılar) temizler
  static Future<void> clearAll() async {
    try {
      final baseDir = await getTemporaryDirectory();
      if (await baseDir.exists()) {
        final List<FileSystemEntity> entities = baseDir.listSync(recursive: false);
        for (final entity in entities) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Açık/kilitli soket veya sistem dosyalarını atla
          }
        }
      }
    } catch (e) {
      debugPrint('Genel önbellek temizleme hatası: $e');
    }
  }
}