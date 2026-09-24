import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/files/temp_file_manager.dart';
import '../../../auth/data/google_auth_service.dart';
import '../../../auth/data/microsoft_auth_service.dart';
import '../../../cloud/data/drive_sync_service.dart';
import '../../../cloud/data/office_to_pdf_service.dart';
import '../../../convert/data/image_to_pdf_converter.dart';
import '../../../convert/data/txt_to_pdf_converter.dart';
import '../../../convert/data/zip_creator_service.dart';
import '../../../convert/data/zip_extractor.dart';
import '../../../convert/domain/conversion_kind.dart';

class HomeOpResult {
  const HomeOpResult.success(this.message) : isSuccess = true;
  const HomeOpResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String message;
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(
      this._googleAuth,
      this._microsoftAuth, {
        OfficeToPdfService officeToPdf = const OfficeToPdfService(),
      }) : _officeToPdf = officeToPdf;

  final GoogleAuthService _googleAuth;
  final MicrosoftAuthService _microsoftAuth;
  final OfficeToPdfService _officeToPdf;

  bool _busy = false;
  String? _statusMessage;
  double _progress = 0.0;
  String _currentFileName = '';
  final List<File> _resultFiles = [];
  bool _isDisposed = false;

  bool get busy => _busy;
  String? get statusMessage => _statusMessage;
  double get progress => _progress;
  String get currentFileName => _currentFileName;
  List<File> get resultFiles => List.unmodifiable(_resultFiles);
  GoogleAuthService get googleAuth => _googleAuth;
  MicrosoftAuthService get microsoftAuth => _microsoftAuth;

  void addResult(File file) {
    _resultFiles.insert(0, file);
    notifyListeners();
  }

  Future<void> removeResult(File file) async {
    _resultFiles.remove(file);
    await TempFileManager.deleteFile(file);
    notifyListeners();
  }

  Future<void> clearAllResults() async {
    for (final file in _resultFiles) {
      await TempFileManager.deleteFile(file);
    }
    _resultFiles.clear();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<HomeOpResult> processFiles({
    required List<File> files,
    required ConversionKind kind,
    bool clearPreviousSession = true,
  }) async {
    if (clearPreviousSession && _resultFiles.isNotEmpty) {
      // Sadece ekranda önceden listelenmiş eski sonuçları temizle:
      for (final file in _resultFiles) {
        await TempFileManager.deleteFile(file);
      }
      _resultFiles.clear();
      if (!_isDisposed) {
        notifyListeners();
      }
    }

    final total = files.length;
    _setBusy(true, message: '$total dosya hazırlanıyor...', progress: 0.01);

    try {
      if (kind == ConversionKind.image) {
        final outputPdf = await ImageToPdfConverter.convert(
          files,
          onProgress: (current, total) {
            _updateProgress(
              progress: current / total,
              currentFile: 'Resim $current / $total işleniyor...',
              message: 'Resimler PDF yapılıyor (%${((current / total) * 100).toInt()})',
            );
          },
        );
        _resultFiles.insert(0, outputPdf);
      } else {
        for (var i = 0; i < total; i++) {
          final file = files[i];
          final name = file.uri.pathSegments.last;

          final baseProgress = i / total;
          final stepWeight = 1.0 / total;

          _updateProgress(
            progress: baseProgress,
            currentFile: name,
            message: 'İşleniyor (${i + 1}/$total)',
          );

          switch (kind) {
            case ConversionKind.office:
              _updateProgress(
                progress: baseProgress + (stepWeight * 0.3),
                currentFile: name,
                message: 'Bulutta PDF\'e dönüştürülüyor (${i + 1}/$total)',
              );
              final converted = await _officeToPdf.convert(
                file,
                googleAuth: _googleAuth,
                microsoftAuth: _microsoftAuth,
              );
              _resultFiles.insert(0, converted);

            case ConversionKind.txt:
              final converted = await TxtToPdfConverter.convert(
                file,
                onProgress: (subProgress, status) {
                  _updateProgress(
                    progress: baseProgress + (stepWeight * subProgress),
                    currentFile: name,
                    message: '$status (${i + 1}/$total)',
                  );
                },
              );
              _resultFiles.insert(0, converted);

            case ConversionKind.zip:
              _updateProgress(
                progress: baseProgress + (stepWeight * 0.5),
                currentFile: name,
                message: 'Arşivden çıkartılıyor (${i + 1}/$total)',
              );
              _resultFiles.insertAll(0, await ZipExtractor.extract(file));

            case ConversionKind.image:
              break;
          }

          _updateProgress(
            progress: (i + 1) / total,
            currentFile: name,
            message: 'Tamamlandı (${i + 1}/$total)',
          );
        }
      }
      return HomeOpResult.success('$total dosya başarıyla dönüştürüldü.');
    } catch (error) {
      return HomeOpResult.failure(mapErrorMessage(error));
    } finally {
      // ZIP dosyası kaynak dosya olduğu için onu sistemden silmiyoruz:
      if (kind != ConversionKind.image && kind != ConversionKind.zip) {
        await TempFileManager.deleteFiles(files);
      }
      _setBusy(false);
    }
  }

  Future<HomeOpResult> createZip(List<File> files) async {
    _setBusy(
      true,
      message: 'ZIP hazırlanıyor...',
      progress: 0.01,
      currentFile: 'Dosyalar taranıyor...',
    );

    try {
      final zipFile = await ZipCreatorService.createZipFromFiles(
        files,
        onProgress: (progress, currentFile, processedBytes, totalBytes) {
          final processedMB = (processedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

          _updateProgress(
            progress: progress,
            currentFile: '$currentFile ($processedMB / $totalMB MB)',
            message: 'Arşivleniyor (%${(progress * 100).toInt()})',
          );
        },
      );

      _resultFiles.insert(0, zipFile);
      return HomeOpResult.success('${files.length} dosya ZIP arşivlendi!');
    } catch (error) {
      return HomeOpResult.failure('ZIP hatası: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<HomeOpResult> backupSingleToDrive(File file) async {
    if (!await _ensureGoogleSignedIn()) {
      return const HomeOpResult.failure('Yedekleme için Google girişi yapılmadı.');
    }

    final fileName = file.uri.pathSegments.last;
    _setBusy(
      true,
      message: 'Drive\'a aktarılıyor...',
      progress: 0.2,
      currentFile: fileName,
    );

    try {
      await DriveSyncService(_googleAuth).uploadPdfToDrive(file);
      _updateProgress(
        progress: 1.0,
        currentFile: fileName,
        message: 'Yedekleme tamamlandı!',
      );
      return HomeOpResult.success('$fileName Drive\'a yüklendi!');
    } catch (error) {
      return HomeOpResult.failure('Yükleme hatası: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<HomeOpResult> backupAllToDrive() async {
    if (_resultFiles.isEmpty) {
      return const HomeOpResult.failure('Yedeklenecek dosya yok.');
    }
    if (!await _ensureGoogleSignedIn()) {
      return const HomeOpResult.failure('Yedekleme için Google girişi onaylanmadı.');
    }

    final total = _resultFiles.length;
    _setBusy(true, message: 'Drive\'a aktarım başlatılıyor...', progress: 0.01);

    try {
      final driveService = DriveSyncService(_googleAuth);
      var count = 0;

      for (final file in _resultFiles) {
        final name = file.uri.pathSegments.last;
        count++;

        _updateProgress(
          progress: count / total,
          currentFile: name,
          message: 'Drive\'a yükleniyor ($count/$total)',
        );

        await driveService.uploadPdfToDrive(file);
      }
      return HomeOpResult.success('$count dosya Drive\'a yedeklendi!');
    } catch (error) {
      return HomeOpResult.failure('Yedekleme hatası: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> shareAll() async {
    if (_resultFiles.isEmpty) return;
    await Share.shareXFiles(_resultFiles.map((file) => XFile(file.path)).toList());
  }

  Future<void> signOut() async {
    if (_microsoftAuth.isSignedIn) await _microsoftAuth.signOut();
    if (_googleAuth.isSignedIn) await _googleAuth.signOut();
  }

  Future<bool> _ensureGoogleSignedIn() async {
    if (_googleAuth.isSignedIn) return true;
    return _googleAuth.signIn();
  }

  void _setBusy(
      bool value, {
        String? message,
        double progress = 0.0,
        String currentFile = '',
      }) {
    _busy = value;
    _statusMessage = value ? message : null;
    _progress = value ? progress : 0.0;
    _currentFileName = value ? currentFile : '';
    notifyListeners();
  }

  void _updateProgress({
    required double progress,
    required String currentFile,
    required String message,
  }) {
    _progress = progress.clamp(0.0, 1.0);
    _currentFileName = currentFile;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final file in _resultFiles) {
      TempFileManager.deleteFile(file);
    }
    _resultFiles.clear();
    TempFileManager.clearAll();
    super.dispose();
  }
}