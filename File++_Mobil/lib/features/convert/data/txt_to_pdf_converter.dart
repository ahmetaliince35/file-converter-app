import 'dart:io';
import 'universal_converter_service.dart';

/// TXT dosyalarını A4 standartlı, bellek korumalı PDF belgesine dönüştüren servis.
class TxtToPdfConverter {
  static Future<File> convert(
    File txtFile, {
    void Function(double progress, String status)? onProgress,
  }) async {
    const service = UniversalConverterService();
    return service.convert(
      file: txtFile,
      target: UniversalTargetFormat.pdf,
      onProgress: onProgress,
    );
  }
}