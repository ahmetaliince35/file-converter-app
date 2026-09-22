import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/error_mapper.dart';
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

/// Ana panelin iş kuralları: dönüşüm, arşiv ve Drive yedekleme.
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
  final List<File> _resultFiles = [];

  bool get busy => _busy;
  String? get statusMessage => _statusMessage;
  List<File> get resultFiles => List.unmodifiable(_resultFiles);
  GoogleAuthService get googleAuth => _googleAuth;
  MicrosoftAuthService get microsoftAuth => _microsoftAuth;

  void addResult(File file) {
    _resultFiles.insert(0, file);
    notifyListeners();
  }

  Future<HomeOpResult> processFiles({
    required List<File> files,
    required ConversionKind kind,
  }) async {
    _setBusy(true, '${files.length} dosya hazırlanıyor...');
    try {
      final total = files.length;
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final name = file.uri.pathSegments.last;
        _setStatus('İşleniyor (${i + 1}/$total)\n$name');

        switch (kind) {
          case ConversionKind.office:
            _resultFiles.insert(
              0,
              await _officeToPdf.convert(
                file,
                googleAuth: _googleAuth,
                microsoftAuth: _microsoftAuth,
              ),
            );
          case ConversionKind.image:
            _resultFiles.insert(0, await ImageToPdfConverter.convert(file));
          case ConversionKind.txt:
            _resultFiles.insert(0, await TxtToPdfConverter.convert(file));
          case ConversionKind.zip:
            _resultFiles.insertAll(0, await ZipExtractor.extract(file));
        }
      }
      return HomeOpResult.success('$total dosya başarıyla dönüştürüldü.');
    } catch (error) {
      return HomeOpResult.failure(mapErrorMessage(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<HomeOpResult> createZip(List<File> files) async {
    _setBusy(true, 'Dosyalar ZIP arşivine ekleniyor...');
    try {
      final zipFile = await ZipCreatorService.createZipFromFiles(files);
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

    _setBusy(true, '${file.uri.pathSegments.last}\nDrive\'a aktarılıyor...');
    try {
      await DriveSyncService(_googleAuth).uploadPdfToDrive(file);
      return HomeOpResult.success('${file.uri.pathSegments.last} Drive\'a yüklendi!');
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
      return const HomeOpResult.failure(
        'Yedekleme için Google girişi onaylanmadı.',
      );
    }

    _setBusy(true, 'Google Drive\'a toplu aktarım başlatılıyor...');
    try {
      final driveService = DriveSyncService(_googleAuth);
      var count = 0;
      for (final file in _resultFiles) {
        await driveService.uploadPdfToDrive(file);
        count++;
        _setStatus('Drive\'a yükleniyor ($count/${_resultFiles.length})...');
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

  void _setBusy(bool value, [String? message]) {
    _busy = value;
    _statusMessage = value ? message : null;
    notifyListeners();
  }

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }
}
