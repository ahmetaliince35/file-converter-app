import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_converter/features/convert/data/universal_converter_service.dart';

void main() {
  group('UniversalConverterService Tests', () {
    test('detects all file categories correctly and strictly excludes media', () {
      expect(
        UniversalConverterService.detectCategory(File('report.pdf')),
        FileFormatCategory.pdf,
      );
      expect(
        UniversalConverterService.detectCategory(File('doc.docx')),
        FileFormatCategory.officeDoc,
      );
      expect(
        UniversalConverterService.detectCategory(File('sheet.xlsx')),
        FileFormatCategory.officeExcel,
      );
      expect(
        UniversalConverterService.detectCategory(File('slides.pptx')),
        FileFormatCategory.officePpt,
      );
      expect(
        UniversalConverterService.detectCategory(File('archive.zip')),
        FileFormatCategory.zip,
      );

      // Ses, video ve resim dosyaları kesinlikle hariç tutulmalıdır (unknown olmalı)
      expect(
        UniversalConverterService.detectCategory(File('photo.jpg')),
        FileFormatCategory.unknown,
      );
      expect(
        UniversalConverterService.detectCategory(File('image.png')),
        FileFormatCategory.unknown,
      );
      expect(
        UniversalConverterService.detectCategory(File('recording.mp3')),
        FileFormatCategory.unknown,
      );
      expect(
        UniversalConverterService.detectCategory(File('video.mp4')),
        FileFormatCategory.unknown,
      );

      // Kod ve metin dosyaları
      expect(
        UniversalConverterService.detectCategory(File('main.dart')),
        FileFormatCategory.textOrCode,
      );
      expect(
        UniversalConverterService.detectCategory(File('script.py')),
        FileFormatCategory.textOrCode,
      );
      expect(
        UniversalConverterService.detectCategory(File('data.json')),
        FileFormatCategory.textOrCode,
      );
      expect(
        UniversalConverterService.detectCategory(File('style.css')),
        FileFormatCategory.textOrCode,
      );
      expect(
        UniversalConverterService.detectCategory(File('index.html')),
        FileFormatCategory.textOrCode,
      );
      expect(
        UniversalConverterService.detectCategory(File('table.csv')),
        FileFormatCategory.textOrCode,
      );
    });

    test('verifies supportedExtensions contains documents/code/zip and excludes media', () {
      expect(UniversalConverterService.supportedExtensions.length, greaterThan(25));
      expect(UniversalConverterService.supportedExtensions.contains('pdf'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('docx'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('xlsx'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('pptx'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('dart'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('json'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('csv'), isTrue);
      expect(UniversalConverterService.supportedExtensions.contains('zip'), isTrue);

      // Ses, video ve resim uzantıları listede olmamalı
      expect(UniversalConverterService.supportedExtensions.contains('png'), isFalse);
      expect(UniversalConverterService.supportedExtensions.contains('jpg'), isFalse);
      expect(UniversalConverterService.supportedExtensions.contains('jpeg'), isFalse);
      expect(UniversalConverterService.supportedExtensions.contains('mp3'), isFalse);
      expect(UniversalConverterService.supportedExtensions.contains('mp4'), isFalse);
      expect(UniversalConverterService.supportedExtensions.contains('wav'), isFalse);
    });

    test('decodeTextBytes handles UTF-8 with BOM, UTF-16 and Latin-1 without error', () {
      // 1. Standart UTF-8
      final utf8Bytes = [104, 101, 108, 108, 111]; // "hello"
      expect(UniversalConverterService.decodeTextBytes(utf8Bytes), 'hello');

      // 2. UTF-8 with BOM [0xEF, 0xBB, 0xBF]
      final utf8BomBytes = [0xEF, 0xBB, 0xBF, 119, 111, 114, 108, 100]; // BOM + "world"
      expect(UniversalConverterService.decodeTextBytes(utf8BomBytes), 'world');

      // 3. UTF-16 LE with BOM [0xFF, 0xFE]
      final utf16LeBytes = [0xFF, 0xFE, 0x61, 0x00, 0x62, 0x00]; // BOM + "ab"
      expect(UniversalConverterService.decodeTextBytes(utf16LeBytes), 'ab');

      // 4. UTF-16 BE with BOM [0xFE, 0xFF]
      final utf16BeBytes = [0xFE, 0xFF, 0x00, 0x63, 0x00, 0x64]; // BOM + "cd"
      expect(UniversalConverterService.decodeTextBytes(utf16BeBytes), 'cd');

      // 5. Boş dizi
      expect(UniversalConverterService.decodeTextBytes([]), '');
    });
  });
}
