import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
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
import '../../../scanner/data/document_scan_adapter.dart';
import '../../../transcribe/data/audio_to_text_converter.dart';
import '../../data/services/file_selector_service.dart';
import '../../domain/models/processed_file_item.dart';

import 'package:dosya_converter/features/convert/data/universal_converter_service.dart';

class HomeOpResult {
  const HomeOpResult.success(this.message) : isSuccess = true;
  const HomeOpResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String message;
}

/// Ana ekranın tüm durum ve iş mantığını yöneten ViewModel.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(
    this._googleAuth,
    this._microsoftAuth, {
    OfficeToPdfService officeToPdf = const OfficeToPdfService(),
    FileSelectorService fileSelector = const FileSelectorService(),
    DocumentScanAdapter scanAdapter = const DocumentScanAdapter(),
    UniversalConverterService universalConverter = const UniversalConverterService(),
  })  : _officeToPdf = officeToPdf,
        _fileSelector = fileSelector,
        _scanAdapter = scanAdapter,
        _universalConverter = universalConverter;

  final GoogleAuthService _googleAuth;
  final MicrosoftAuthService _microsoftAuth;
  final OfficeToPdfService _officeToPdf;
  final FileSelectorService _fileSelector;
  final DocumentScanAdapter _scanAdapter;
  final UniversalConverterService _universalConverter;

  bool _busy = false;
  String? _statusMessage;
  double _progress = 0.0;
  String _currentFileName = '';
  final List<ProcessedFileItem> _resultItems = [];
  String _searchQuery = '';
  bool _isDisposed = false;

  // Getters
  bool get busy => _busy;
  String? get statusMessage => _statusMessage;
  double get progress => _progress;
  String get currentFileName => _currentFileName;
  String get searchQuery => _searchQuery;

  List<ProcessedFileItem> get resultItems => List.unmodifiable(_resultItems);

  /// Filtrelenmiş veya arama yapılmış hazır dosya listesi
  List<ProcessedFileItem> get filteredResults {
    if (_searchQuery.trim().isEmpty) return resultItems;
    final q = _searchQuery.trim().toLowerCase();
    return _resultItems.where((item) => item.name.toLowerCase().contains(q)).toList();
  }

  /// Geriye uyumluluk için ham File listesi
  List<File> get resultFiles => _resultItems.map((e) => e.file).toList();

  GoogleAuthService get googleAuth => _googleAuth;
  MicrosoftAuthService get microsoftAuth => _microsoftAuth;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void addResult(File file) {
    // Listede zaten varsa tekrar ekleme
    if (!_resultItems.any((e) => e.file.path == file.path)) {
      _resultItems.insert(0, ProcessedFileItem(file: file));
      notifyListeners();
    }
  }

  Future<void> removeResult(File file) async {
    _resultItems.removeWhere((e) => e.file.path == file.path);
    await TempFileManager.deleteFile(file);
    notifyListeners();
  }

  Future<void> removeResultItem(ProcessedFileItem item) async {
    _resultItems.remove(item);
    await TempFileManager.deleteFile(item.file);
    notifyListeners();
  }

  Future<void> clearAllResults() async {
    for (final item in _resultItems) {
      await TempFileManager.deleteFile(item.file);
    }
    _resultItems.clear();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Dosya seçip kategoriye göre doğrudan dönüştürme akışı
  Future<HomeOpResult?> pickAndConvertCategory({
    required List<String> extensions,
    required ConversionKind kind,
  }) async {
    final selection = await _fileSelector.pickCategoryFiles(extensions: extensions);
    if (selection.isCancelled) return null;
    if (selection.hasError) {
      return HomeOpResult.failure(selection.errorMessage!);
    }
    return processFiles(files: selection.files, kind: kind);
  }

  /// Kamera ile belge tarama akışı
  Future<HomeOpResult?> scanDocument() async {
    final scannedFile = await _scanAdapter.startScan();
    if (scannedFile == null) return null;
    addResult(scannedFile);
    return const HomeOpResult.success('Taranmış A4 PDF başarıyla oluşturuldu!');
  }

  /// ZIP arşivi oluşturma akışı
  Future<HomeOpResult?> pickAndCreateZip() async {
    const int maxBytes = 1800 * 1024 * 1024;
    final selection = await _fileSelector.pickAnyFiles(
      allowMultiple: true,
      maxSizeBytes: maxBytes,
    );

    if (selection.isCancelled) return null;
    if (selection.hasError) {
      return HomeOpResult.failure(selection.errorMessage!);
    }
    return createZip(selection.files);
  }

  /// Evrensel Dönüştürücü: Herhangi bir dosyayı seçip TXT veya PDF'e dönüştürür
  Future<HomeOpResult?> pickAndConvertUniversal({
    required UniversalTargetFormat targetFormat,
    List<String>? customExtensions,
  }) async {
    final selection = await _fileSelector.pickUniversalFiles(
      customExtensions: customExtensions,
      allowMultiple: true,
    );

    if (selection.isCancelled) return null;
    if (selection.hasError) {
      return HomeOpResult.failure(selection.errorMessage!);
    }

    return convertUniversalFiles(
      files: selection.files,
      targetFormat: targetFormat,
    );
  }

  /// Seçilen dosyaları TXT veya PDF'e dönüştürür ve sonuç listesine ekler
  Future<HomeOpResult> convertUniversalFiles({
    required List<File> files,
    required UniversalTargetFormat targetFormat,
  }) async {
    final total = files.length;
    final targetName = targetFormat == UniversalTargetFormat.pdf ? 'PDF' : 'TXT';
    _setBusy(true, message: '$total dosya $targetName formatına dönüştürülüyor...', progress: 0.01);

    try {
      int successCount = 0;
      for (var i = 0; i < total; i++) {
        final file = files[i];
        final name = file.uri.pathSegments.last;

        _updateProgress(
          progress: (i / total) + 0.05,
          currentFile: name,
          message: '$name ➔ $targetName hazırlanıyor (${i + 1}/$total)',
        );

        final result = await _universalConverter.convert(
          file: file,
          target: targetFormat,
          googleAuth: _googleAuth,
          microsoftAuth: _microsoftAuth,
          onProgress: (subProgress, status) {
            final overall = (i / total) + (subProgress / total);
            _updateProgress(
              progress: overall.clamp(0.0, 0.99),
              currentFile: name,
              message: '$status (${i + 1}/$total)',
            );
          },
        );

        addResult(result);
        successCount++;
      }

      return HomeOpResult.success('$successCount dosya başarıyla $targetName olarak hazırlandı!');
    } catch (e) {
      return HomeOpResult.failure(mapErrorMessage(e));
    } finally {
      _setBusy(false);
    }
  }

  Future<HomeOpResult> processFiles({
    required List<File> files,
    required ConversionKind kind,
    bool clearPreviousSession = true,
  }) async {
    if (clearPreviousSession && _resultItems.isNotEmpty) {
      for (final item in _resultItems) {
        await TempFileManager.deleteFile(item.file);
      }
      _resultItems.clear();
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
          onProgress: (current, totalCount) {
            _updateProgress(
              progress: current / totalCount,
              currentFile: 'Resim $current / $totalCount işleniyor...',
              message: 'Resimler PDF yapılıyor (%${((current / totalCount) * 100).toInt()})',
            );
          },
        );
        addResult(outputPdf);
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
              addResult(converted);
              break;

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
              addResult(converted);
              break;

            case ConversionKind.zip:
              _updateProgress(
                progress: baseProgress + (stepWeight * 0.5),
                currentFile: name,
                message: 'Arşivden çıkartılıyor (${i + 1}/$total)',
              );
              final extracted = await ZipExtractor.extract(file);
              for (final f in extracted) {
                addResult(f);
              }
              break;

            case ConversionKind.audio:
              final apiKey = await AudioToTextConverter.getSavedApiKey();
              if (apiKey == null || apiKey.isEmpty) {
                throw Exception('Ses dönüştürmek için önce Deepgram API anahtarınızı tanımlamalısınız.');
              }

              _updateProgress(
                progress: baseProgress + (stepWeight * 0.4),
                currentFile: name,
                message: 'Yapay zeka sesi metne dönüştürüyor (${i + 1}/$total)',
              );
              final converted = await AudioToTextConverter.convert(file);
              addResult(converted);
              break;

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
      if (kind != ConversionKind.image && kind != ConversionKind.zip && kind != ConversionKind.audio) {
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

      addResult(zipFile);
      return HomeOpResult.success('${files.length} dosya ZIP arşivlendi!');
    } catch (error) {
      return HomeOpResult.failure('ZIP hatası: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<HomeOpResult> previewFile(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        return HomeOpResult.failure('Dosya açılamadı: ${result.message}');
      }
      return const HomeOpResult.success('Dosya açıldı');
    } catch (e) {
      return HomeOpResult.failure('Önizleme başlatılamadı: $e');
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
    if (_resultItems.isEmpty) {
      return const HomeOpResult.failure('Yedeklenecek dosya yok.');
    }
    if (!await _ensureGoogleSignedIn()) {
      return const HomeOpResult.failure('Yedekleme için Google girişi onaylanmadı.');
    }

    final total = _resultItems.length;
    _setBusy(true, message: 'Drive\'a aktarım başlatılıyor...', progress: 0.01);

    try {
      final driveService = DriveSyncService(_googleAuth);
      var count = 0;

      for (final item in _resultItems) {
        final name = item.name;
        count++;

        _updateProgress(
          progress: count / total,
          currentFile: name,
          message: 'Drive\'a yükleniyor ($count/$total)',
        );

        await driveService.uploadPdfToDrive(item.file);
      }
      return HomeOpResult.success('$count dosya Drive\'a yedeklendi!');
    } catch (error) {
      return HomeOpResult.failure('Yedekleme hatası: $error');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> shareSingle(File file) async {
    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  Future<void> shareAll() async {
    if (_resultItems.isEmpty) return;
    final filesToShare = _resultItems.where((e) => e.file.existsSync()).map((e) => XFile(e.file.path)).toList();
    if (filesToShare.isNotEmpty) {
      await Share.shareXFiles(filesToShare);
    }
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
    TempFileManager.deleteFiles(resultFiles);
    _resultItems.clear();
    super.dispose();
  }
}