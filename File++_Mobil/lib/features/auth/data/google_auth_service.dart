import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthService extends ChangeNotifier {
  // Temel kimlik doğrulaması ve uygulama dosyaları erişim yetkisi
  static const List<String> _scopes = [
    'email',
    drive.DriveApi.driveFileScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _currentUser;
  auth.AuthClient? _authenticatedClient;
  bool _isChecking = true;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && _authenticatedClient != null;
  bool get isChecking => _isChecking;
  auth.AuthClient? get authenticatedClient => _authenticatedClient;

  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      _currentUser = account;

      // Önceki istemciyi güvenle kapat
      _authenticatedClient?.close();
      _authenticatedClient = null;

      if (_currentUser != null) {
        try {
          _authenticatedClient = await _googleSignIn.authenticatedClient();
        } catch (e) {
          debugPrint('Google client oluşturma dinleyici hatası: $e');
          _authenticatedClient = null;
        }
      }

      _isChecking = false;
      notifyListeners();
    });
  }

  Future<void> initSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        _authenticatedClient = await _googleSignIn.authenticatedClient();
      }
    } catch (e) {
      debugPrint('Google sessiz oturum hatası: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> signIn() async {
    try {
      _isChecking = true;
      notifyListeners();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        _isChecking = false;
        notifyListeners();
        return false;
      }

      // Yarış durumunu engellemek için doğrudan authenticatedClient'ı alıp bekle
      _currentUser = account;
      _authenticatedClient = await _googleSignIn.authenticatedClient();

      _isChecking = false;
      notifyListeners();
      return _authenticatedClient != null;
    } catch (e) {
      debugPrint('Google Sign-In Hatası: $e');
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out Hatası: $e');
    }
    _authenticatedClient?.close();
    _authenticatedClient = null;
    _currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authenticatedClient?.close();
    super.dispose();
  }
}