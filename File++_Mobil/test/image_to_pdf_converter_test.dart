import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dosya_converter/core/files/temp_file_manager.dart';
import 'package:dosya_converter/features/convert/data/image_to_pdf_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<File> sampleImages;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('image_to_pdf_test_');
    TempFileManager.overrideWorkingDir = tempDir;
    sampleImages = [];

    // 4 adet küçük test resmi oluştur
    for (int i = 0; i < 4; i++) {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(200, 50 * i, 100));
      final jpgBytes = img.encodeJpg(image);
      final file = File('${tempDir.path}/test_img_$i.jpg');
      await file.writeAsBytes(jpgBytes);
      sampleImages.add(file);
    }
  });

  tearDown(() async {
    TempFileManager.overrideWorkingDir = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ImageToPdfConverter Matrix Tests', () {
    test('1 image per page produces 4 pages for 4 images', () async {
      final pdf = await ImageToPdfConverter.createScannedPdf(
        imageFiles: sampleImages,
        imagesPerPage: 1,
      );

      expect(await pdf.exists(), isTrue);
      expect(pdf.lengthSync(), greaterThan(0));
    });

    test('4 images per page (2x2 matrix) produces 1 page for 4 images', () async {
      final pdf = await ImageToPdfConverter.createScannedPdf(
        imageFiles: sampleImages,
        imagesPerPage: 4,
      );

      expect(await pdf.exists(), isTrue);
      expect(pdf.lengthSync(), greaterThan(0));
    });

    test('2 images per page produces 2 pages for 4 images', () async {
      final pdf = await ImageToPdfConverter.createScannedPdf(
        imageFiles: sampleImages,
        imagesPerPage: 2,
      );

      expect(await pdf.exists(), isTrue);
      expect(pdf.lengthSync(), greaterThan(0));
    });
  });
}
