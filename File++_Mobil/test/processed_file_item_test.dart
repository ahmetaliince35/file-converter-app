import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_converter/features/home/domain/models/processed_file_item.dart';

void main() {
  group('ProcessedFileItem Tests', () {
    test('detects PDF category and labels correctly', () {
      final item = ProcessedFileItem(file: File('test_document.pdf'));

      expect(item.name, 'test_document.pdf');
      expect(item.extension, 'pdf');
      expect(item.category, FileCategory.pdf);
      expect(item.typeLabel, 'PDF Belgesi');
      expect(item.icon, Icons.picture_as_pdf_rounded);
      expect(item.accentColor, const Color(0xFFC46B6B));
    });

    test('detects Office Word category correctly', () {
      final item = ProcessedFileItem(file: File('report.docx'));

      expect(item.name, 'report.docx');
      expect(item.extension, 'docx');
      expect(item.category, FileCategory.doc);
      expect(item.typeLabel, 'Word Belgesi');
      expect(item.icon, Icons.article_rounded);
      expect(item.accentColor, const Color(0xFF4A7C9F));
    });

    test('detects Excel category correctly', () {
      final item = ProcessedFileItem(file: File('data.xlsx'));

      expect(item.category, FileCategory.spreadsheet);
      expect(item.typeLabel, 'Excel Tablosu');
      expect(item.icon, Icons.table_chart_rounded);
      expect(item.accentColor, const Color(0xFF4E8772));
    });

    test('detects ZIP archive category correctly', () {
      final item = ProcessedFileItem(file: File('archive.zip'));

      expect(item.category, FileCategory.archive);
      expect(item.typeLabel, 'ZIP Arşivi');
      expect(item.icon, Icons.folder_zip_rounded);
    });

    test('detects Source Code category correctly', () {
      final dartItem = ProcessedFileItem(file: File('main.dart'));
      expect(dartItem.category, FileCategory.code);
      expect(dartItem.typeLabel, 'Dart Kodu');
      expect(dartItem.icon, Icons.code_rounded);
      expect(dartItem.accentColor, const Color(0xFF6B72B8));

      final pyItem = ProcessedFileItem(file: File('script.py'));
      expect(pyItem.category, FileCategory.code);
      expect(pyItem.typeLabel, 'Python Kodu');

      final rustItem = ProcessedFileItem(file: File('lib.rs'));
      expect(rustItem.category, FileCategory.code);
      expect(rustItem.typeLabel, 'Rust Kodu');
    });

    test('handles file size formatting', () {
      final item = ProcessedFileItem(file: File('empty.pdf'));
      expect(item.formattedSize, '0 KB');
    });
  });
}
