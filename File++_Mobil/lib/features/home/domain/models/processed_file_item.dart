import 'dart:io';
import 'package:flutter/material.dart';

enum FileCategory {
  pdf,
  doc,
  spreadsheet,
  presentation,
  text,
  code,
  archive,
  image,
  audio,
  other,
}

/// Dönüştürülen veya oluşturulan çıktıyı temsil eden temiz Domain Modeli.
@immutable
class ProcessedFileItem {
  final File file;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime createdAt;

  ProcessedFileItem({
    required this.file,
    DateTime? createdAt,
  })  : name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'dosya',
        extension = _extractExtension(file),
        sizeBytes = _getFileSize(file),
        createdAt = createdAt ?? DateTime.now();

  static String _extractExtension(File file) {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '';
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot != -1 && lastDot < fileName.length - 1) {
      return fileName.substring(lastDot + 1).toLowerCase();
    }
    return '';
  }

  static int _getFileSize(File file) {
    try {
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (_) {}
    return 0;
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '0 KB';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static const Set<String> _codeExtensions = {
    'dart', 'js', 'mjs', 'cjs', 'jsx', 'ts', 'mts', 'cts', 'tsx', 'vue', 'svelte', 'astro',
    'html', 'htm', 'xhtml', 'css', 'scss', 'sass', 'less',
    'py', 'pyw', 'pyi', 'pyx', 'r', 'rmd', 'jl', 'ipynb',
    'c', 'h', 'cpp', 'hpp', 'cc', 'hh', 'cxx', 'hxx', 'ino',
    'cs', 'csx', 'rs', 'go', 'zig', 'nim', 'd', 'v', 'odin', 'pas', 'pp', 'asm', 's',
    'swift', 'm', 'mm',
    'java', 'kt', 'kts', 'scala', 'sc', 'groovy', 'gvy', 'gradle', 'clj', 'cljs',
    'sh', 'bash', 'zsh', 'fish', 'ksh', 'ps1', 'psm1', 'bat', 'cmd',
    'lua', 'rb', 'rbw', 'rake', 'php', 'phtml', 'pl', 'pm', 'tcl', 'awk', 'sed',
    'json', 'jsonc', 'json5', 'yaml', 'yml', 'toml', 'xml', 'svg', 'csv', 'tsv',
    'ini', 'conf', 'config', 'cfg', 'properties', 'env', 'dotenv', 'lock',
    'mod', 'sum',
    'sql', 'mysql', 'pgsql', 'sqlite', 'prisma', 'graphql', 'gql',
    'dockerfile', 'containerfile', 'makefile', 'cmake', 'vagrantfile', 'jenkinsfile',
    'md', 'markdown', 'mdx', 'rst', 'tex', 'latex', 'log',
    'glsl', 'hlsl', 'frag', 'vert', 'shader',
    'hs', 'lhs', 'elm', 'erl', 'hrl', 'ex', 'exs', 'fs', 'fsi', 'fsx', 'ml', 'mli',
  };

  FileCategory get category {
    if (_codeExtensions.contains(extension)) {
      return FileCategory.code;
    }

    switch (extension) {
      case 'pdf':
        return FileCategory.pdf;
      case 'doc':
      case 'docx':
        return FileCategory.doc;
      case 'xls':
      case 'xlsx':
        return FileCategory.spreadsheet;
      case 'ppt':
      case 'pptx':
        return FileCategory.presentation;
      case 'txt':
      case 'rtf':
        return FileCategory.text;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return FileCategory.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'bmp':
        return FileCategory.image;
      case 'mp3':
      case 'm4a':
      case 'wav':
      case 'flac':
      case 'aac':
        return FileCategory.audio;
      default:
        return FileCategory.other;
    }
  }

  String get typeLabel {
    switch (category) {
      case FileCategory.pdf:
        return 'PDF Belgesi';
      case FileCategory.doc:
        return 'Word Belgesi';
      case FileCategory.spreadsheet:
        return 'Excel Tablosu';
      case FileCategory.presentation:
        return 'Sunum';
      case FileCategory.text:
        return 'Metin Belgesi';
      case FileCategory.code:
        return _formatCodeLabel(extension);
      case FileCategory.archive:
        return 'ZIP Arşivi';
      case FileCategory.image:
        return 'Görsel';
      case FileCategory.audio:
        return 'Ses Kaydı';
      case FileCategory.other:
        return extension.toUpperCase();
    }
  }

  static String _formatCodeLabel(String ext) {
    switch (ext) {
      case 'dart':
        return 'Dart Kodu';
      case 'py':
      case 'pyw':
        return 'Python Kodu';
      case 'js':
      case 'mjs':
      case 'cjs':
      case 'jsx':
        return 'JavaScript';
      case 'ts':
      case 'tsx':
        return 'TypeScript';
      case 'html':
      case 'htm':
        return 'HTML Belgesi';
      case 'css':
      case 'scss':
      case 'sass':
        return 'CSS / Stil';
      case 'java':
        return 'Java Kodu';
      case 'kt':
      case 'kts':
        return 'Kotlin Kodu';
      case 'swift':
        return 'Swift Kodu';
      case 'rs':
        return 'Rust Kodu';
      case 'go':
        return 'Go Kodu';
      case 'c':
      case 'h':
        return 'C Kaynak Kodu';
      case 'cpp':
      case 'hpp':
      case 'cc':
        return 'C++ Kaynak Kodu';
      case 'cs':
        return 'C# Kodu';
      case 'zig':
        return 'Zig Kodu';
      case 'php':
        return 'PHP Betiği';
      case 'rb':
        return 'Ruby Kodu';
      case 'sql':
      case 'prisma':
        return 'SQL / Veritabanı';
      case 'json':
      case 'jsonc':
        return 'JSON Verisi';
      case 'yaml':
      case 'yml':
      case 'toml':
        return 'Yapılandırma';
      case 'xml':
      case 'svg':
        return 'XML / SVG';
      case 'sh':
      case 'bash':
      case 'zsh':
      case 'ps1':
      case 'bat':
        return 'Kabuk Betiği';
      case 'md':
      case 'markdown':
        return 'Markdown Notu';
      default:
        return '${ext.toUpperCase()} Kodu';
    }
  }

  IconData get icon {
    switch (category) {
      case FileCategory.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileCategory.doc:
        return Icons.article_rounded;
      case FileCategory.spreadsheet:
        return Icons.table_chart_rounded;
      case FileCategory.presentation:
        return Icons.slideshow_rounded;
      case FileCategory.text:
        return Icons.description_rounded;
      case FileCategory.code:
        return Icons.code_rounded;
      case FileCategory.archive:
        return Icons.folder_zip_rounded;
      case FileCategory.image:
        return Icons.image_rounded;
      case FileCategory.audio:
        return Icons.audiotrack_rounded;
      case FileCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get accentColor {
    switch (category) {
      case FileCategory.pdf:
        return const Color(0xFFC46B6B); // Soft Rose / Brick Red
      case FileCategory.doc:
        return const Color(0xFF4A7C9F); // Soft Slate Blue
      case FileCategory.spreadsheet:
        return const Color(0xFF4E8772); // Soft Sage Green
      case FileCategory.presentation:
        return const Color(0xFFC88A58); // Soft Warm Terracotta
      case FileCategory.text:
        return const Color(0xFFD4A373); // Soft Honey Sand
      case FileCategory.code:
        return const Color(0xFF6B72B8); // Soft Muted Indigo
      case FileCategory.archive:
        return const Color(0xFF8E7CB0); // Soft Lavender Violet
      case FileCategory.image:
        return const Color(0xFF5A8FA8); // Soft Steel Blue
      case FileCategory.audio:
        return const Color(0xFFBD7B9D); // Soft Dusty Rose Pink
      case FileCategory.other:
        return const Color(0xFF7A8288); // Soft Warm Slate
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessedFileItem &&
          runtimeType == other.runtimeType &&
          file.path == other.file.path;

  @override
  int get hashCode => file.path.hashCode;
}
