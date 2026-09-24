import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/google_auth_service.dart';
import '../../data/microsoft_auth_service.dart';

/// Kimlik sağlayıcılarını ve misafir oturumunu tek bir ekran durumunda birleştirir.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._googleAuth, this._microsoftAuth) {
    _googleAuth.addListener(_notify);
    _microsoftAuth.addListener(_notify);
  }

  static const String _guestKey = 'is_guest_mode';
  final GoogleAuthService _googleAuth;
  final MicrosoftAuthService _microsoftAuth;

  bool _initialized = false;
  bool _isGuest = false;

  bool get isLoading => _googleAuth.isChecking || _microsoftAuth.isChecking;
  bool get isGuest => _isGuest;
  bool get isSignedIn => _googleAuth.isSignedIn || _microsoftAuth.isSignedIn || _isGuest;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool(_guestKey) ?? false;

    await Future.wait([
      _googleAuth.initSilently(),
      _microsoftAuth.initSilently(),
    ]);

    // Eğer Google veya Microsoft oturumu açılmışsa misafir modunu otomatik sıfırla
    if (_googleAuth.isSignedIn || _microsoftAuth.isSignedIn) {
      _isGuest = false;
      await prefs.setBool(_guestKey, false);
    }
  }

  /// Kullanıcının hesap bağlamadan uygulamayı kullanmasını sağlar
  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = true;
    await prefs.setBool(_guestKey, true);
    notifyListeners();
  }

  /// Çıkış yapıldığında misafir modunu da sonlandırır
  Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = false;
    await prefs.setBool(_guestKey, false);
    notifyListeners();
  }

  void _notify() => notifyListeners();

  @override
  void dispose() {
    _googleAuth.removeListener(_notify);
    _microsoftAuth.removeListener(_notify);
    super.dispose();
  }
}