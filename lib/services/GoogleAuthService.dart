import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthService extends ChangeNotifier {
  static const List<String> _scopes = [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveAppdataScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _currentUser;
  auth.AuthClient? _authenticatedClient;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  auth.AuthClient? get authenticatedClient => _authenticatedClient;

  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      _currentUser = account;
      if (_currentUser != null) {
        _authenticatedClient = await _googleSignIn.authenticatedClient();
      } else {
        _authenticatedClient = null;
      }
      notifyListeners();
    });

    _googleSignIn.signInSilently();
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      _currentUser = account;
      _authenticatedClient = await _googleSignIn.authenticatedClient();
      notifyListeners();
      return true;
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
    _currentUser = null;
    _authenticatedClient = null;
    notifyListeners();
  }
}