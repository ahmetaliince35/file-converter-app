import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:dosya_converter/core/navigation/app_navigator.dart';
import 'package:dosya_converter/core/widgets/feedback_snack_bar.dart';
import 'package:dosya_converter/features/convert/presentation/screens/image_to_pdf_screen.dart';
import 'package:dosya_converter/features/convert/presentation/screens/universal_converter_screen.dart';
import 'package:dosya_converter/features/transcribe/presentation/audio_to_text_screen.dart';

/// Dış uygulamalardan (WhatsApp, Dosya Yöneticisi, Tarayıcı vb.) "Birlikte Aç"
/// veya "Paylaş" ile uygulamaya gönderilen dosyaları yakalayıp doğru ekrana yönlendiren servis.
class IncomingFileService {
  IncomingFileService._internal();
  static final IncomingFileService instance = IncomingFileService._internal();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.ahmet.file_converter/incoming_files');

  StreamSubscription? _mediaStreamSub;
  bool _isInitialized = false;
  String? _lastHandledPath;
  DateTime? _lastHandledTime;

  /// Servisi başlatır ve gelen dosyaları dinlemeye başlar.
  void initialize({void Function(List<File> files)? onFilesReceived}) {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Android Doğrudan Yerel Kanal Dinleyicisi (En stabil yöntem)
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesReceived') {
        final List<dynamic>? args = call.arguments as List<dynamic>?;
        if (args != null && args.isNotEmpty) {
          final paths = args.map((e) => e.toString()).toList();
          _processPaths(paths, onFilesReceived: onFilesReceived);
        }
      }
    });

    // Android Soğuk Başlatma (Cold Start): Uygulama açılırken gelen dosya var mı?
    _checkNativeInitialFiles(onFilesReceived: onFilesReceived);

    // 2. iOS ve Yedek Dinleyici (ReceiveSharingIntent)
    _mediaStreamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final paths = value.map((f) => f.path).toList();
          _processPaths(paths, onFilesReceived: onFilesReceived);
        }
      },
      onError: (err) {
        debugPrint('IncomingFileService Stream hatası: $err');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final paths = value.map((f) => f.path).toList();
        _processPaths(paths, onFilesReceived: onFilesReceived);
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((err) {
      debugPrint('IncomingFileService InitialMedia hatası: $err');
    });
  }

  Future<void> _checkNativeInitialFiles({void Function(List<File> files)? onFilesReceived}) async {
    try {
      final List<dynamic>? initialFiles =
          await _nativeChannel.invokeMethod<List<dynamic>>('getInitialFiles');
      if (initialFiles != null && initialFiles.isNotEmpty) {
        final paths = initialFiles.map((e) => e.toString()).toList();
        _processPaths(paths, onFilesReceived: onFilesReceived);
      }
    } catch (e) {
      debugPrint('Native getInitialFiles hatası: $e');
    }
  }

  void _processPaths(
    List<String> rawPaths, {
    void Function(List<File> files)? onFilesReceived,
  }) {
    final validFiles = <File>[];

    for (final rawPath in rawPaths) {
      final file = _sanitizeToFile(rawPath);
      if (file != null) {
        validFiles.add(file);
      }
    }

    if (validFiles.isEmpty) return;

    // Çift tetiklemeyi önle (Debounce 1 saniye)
    final firstPath = validFiles.first.path;
    final now = DateTime.now();
    if (_lastHandledPath == firstPath &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 1)) {
      return;
    }
    _lastHandledPath = firstPath;
    _lastHandledTime = now;

    if (onFilesReceived != null) {
      onFilesReceived(validFiles);
    } else {
      routeFilesSmartly(validFiles);
    }
  }

  /// Dosyaları türlerine göre uygun stüdyo ekranına yönlendirir.
  Future<void> routeFilesSmartly(List<File> files) async {
    if (files.isEmpty) return;
    debugPrint('IncomingFileService: Dosya yönlendiriliyor -> ${files.first.path}');

    // 1. Tüm dosyalar görsel ise -> Resimden PDF Stüdyosu
    final isAllImages = files.every((f) => _isImageFile(f.path));
    if (isAllImages) {
      await _navigateToScreen(ImageToPdfScreen(initialImages: files));
      _showSuccessFeedback('Görseller PDF Stüdyosu\'na aktarıldı');
      return;
    }

    // 2. Ses dosyası ise -> Ses Dönüştürücü / Transkript Stüdyosu
    final firstAudio = files.firstWhere(
      (f) => _isAudioFile(f.path),
      orElse: () => File(''),
    );
    if (firstAudio.path.isNotEmpty) {
      await _navigateToScreen(AudioToTextScreen(initialAudioFile: firstAudio));
      _showSuccessFeedback('Ses kaydı Transkript Stüdyosu\'na aktarıldı');
      return;
    }

    // 3. Belgeler, kodlar, arşivler ve diğerleri -> Evrensel Dönüştürücü
    final targetFile = files.first;
    await _navigateToScreen(UniversalConverterScreen(initialFile: targetFile));
    _showSuccessFeedback('${p.basename(targetFile.path)} stüdyoya yüklendi');
  }

  void _showSuccessFeedback(String message) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      showFeedbackSnackBar(
        ctx,
        message: message,
        icon: Icons.file_open_rounded,
        backgroundColor: const Color(0xFF4E8772),
      );
    }
  }

  /// Navigator hazır olana kadar bekleyip ekranı açar
  Future<void> _navigateToScreen(Widget screen) async {
    int attempts = 0;
    while (appNavigatorKey.currentState == null && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator != null && navigator.mounted) {
      navigator.push(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  static File? _sanitizeToFile(String rawPath) {
    String path = rawPath.trim();
    if (path.isEmpty) return null;

    if (path.startsWith('file://')) {
      try {
        path = Uri.parse(path).toFilePath();
      } catch (_) {
        path = path.replaceFirst('file://', '');
      }
    }

    try {
      path = Uri.decodeFull(path);
    } catch (_) {}

    final file = File(path);
    return file.existsSync() ? file : null;
  }

  static bool _isImageFile(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    const imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic', 'heif'};
    return imageExtensions.contains(ext);
  }

  static bool _isAudioFile(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    const audioExtensions = {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma', 'webm'};
    return audioExtensions.contains(ext);
  }

  void dispose() {
    _mediaStreamSub?.cancel();
    _mediaStreamSub = null;
    _isInitialized = false;
  }
}
