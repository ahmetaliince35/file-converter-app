import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthService extends ChangeNotifier {
  // Sadece uygulamanın oluşturduğu dosyaları yönetmek için yeterli kapsam
  static const List<String> _scopes = [
    drive.DriveApi.driveFileScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _currentUser;
  auth.AuthClient? _authenticatedClient;
  bool _isChecking = true;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isChecking => _isChecking;
  auth.AuthClient? get authenticatedClient => _authenticatedClient;

  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      _currentUser = account;

      // Eski istemciyi temizle ve kapat
      _authenticatedClient?.close();

      if (_currentUser != null) {
        try {
          _authenticatedClient = await _googleSignIn.authenticatedClient();
        } catch (e) {
          debugPrint('Google client oluşturma hatası: $e');
          _authenticatedClient = null;
        }
      } else {
        _authenticatedClient = null;
      }
      _isChecking = false;
      notifyListeners();
    });
  }

  Future<void> initSilently() async {
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Google sessiz oturum hatası: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      // onCurrentUserChanged zaten authenticatedClient'ı kurup notifyListeners() çağıracaktır.
      return account != null;
    } catch (e) {
      debugPrint('Google Sign-In Hatası: $e');
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