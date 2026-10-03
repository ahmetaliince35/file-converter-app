import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dosya_converter/features/convert/data/zip_archive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleZipFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zip_test_dir_');

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    // Test amaçlı bir ZIP arşivi hazırla
    final archive = Archive();

    // 1. Çevrilebilir belgeler
    final docData = utf8.encode('Merhaba Dunya Docx');
    archive.addFile(ArchiveFile('notes.docx', docData.length, docData));

    final dartData = utf8.encode('void main() => print("test");');
    archive.addFile(ArchiveFile('code.dart', dartData.length, dartData));

    // 2. Çevrilemez medya dosyaları (ses, resim)
    final mp3Data = [0, 1, 2, 3, 4];
    archive.addFile(ArchiveFile('music.mp3', mp3Data.length, mp3Data));

    final pngData = [137, 80, 78, 71];
    archive.addFile(ArchiveFile('photo.png', pngData.length, pngData));

    final zipData = ZipEncoder().encode(archive);
    sampleZipFile = File(p.join(tempDir.path, 'sample.zip'));
    await sampleZipFile.writeAsBytes(zipData!);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ZipArchiveService Tests', () {
    test('inspectZip safely extracts metadata and identifies convertible documents', () async {
      const service = ZipArchiveService();
      final entries = await service.inspectZip(sampleZipFile);

      expect(entries.length, equals(4));

      final docEntry = entries.firstWhere((e) => e.name == 'notes.docx');
      expect(docEntry.isConvertible, isTrue);
      expect(docEntry.extension, equals('docx'));

      final dartEntry = entries.firstWhere((e) => e.name == 'code.dart');
      expect(dartEntry.isConvertible, isTrue);

      final mp3Entry = entries.firstWhere((e) => e.name == 'music.mp3');
      expect(mp3Entry.isConvertible, isFalse);

      final pngEntry = entries.firstWhere((e) => e.name == 'photo.png');
      expect(pngEntry.isConvertible, isFalse);
    });

    test('extractSelectedFiles extracts only the chosen files without memory crash', () async {
      const service = ZipArchiveService();
      final extracted = await service.extractSelectedFiles(
        zipFile: sampleZipFile,
        selectedPaths: ['notes.docx'],
      );

      expect(extracted.length, equals(1));
      expect(p.basename(extracted.first.path), contains('notes.docx'));
      expect(await extracted.first.exists(), isTrue);

      final content = await extracted.first.readAsString();
      expect(content, equals('Merhaba Dunya Docx'));
    });
  });
}
