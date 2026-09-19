import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google hesabıyla giriş + Drive senkronu için gerekli auth başlıklarını
/// (authHeaders) yönetir. Sadece "Drive'a Senkronize Et" özelliği için
/// kullanılır; dönüştürme işlemleri bu servisten bağımsız, tamamen offline
/// çalışır.
class GoogleAuthService extends ChangeNotifier {
  // Sadece uygulamanın oluşturduğu/açtığı dosyalara erişim izni ister.
  // Kullanıcının tüm Drive'ına erişim istemez (daha güvenli, Google onayı
  // için de daha kolay).
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      notifyListeners();
    });
    // Uygulama açılışında sessizce önceki oturumu geri yükle.
    _googleSignIn.signInSilently();
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      notifyListeners();
      return account != null;
    } catch (e) {
      debugPrint('Google Sign-In hatası: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Drive API çağrıları için gerekli HTTP başlıklarını (access token) döner.
  Future<Map<String, String>> getAuthHeaders() async {
    if (_currentUser == null) {
      throw StateError('Önce Google hesabıyla giriş yapılmalı.');
    }
    return _currentUser!.authHeaders;
  }
}