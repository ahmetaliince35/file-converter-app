import 'package:flutter/foundation.dart';

import '../../../../services/GoogleAuthService.dart';
import '../../../../services/microsoft_auth_service.dart';

/// Kimlik sağlayıcılarını tek bir ekran durumunda birleştirir.
///
/// Ekranlar sağlayıcıların uygulama ayrıntılarını bilmek yerine bu ViewModel
/// üzerinden oturum durumunu izlemelidir.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._googleAuth, this._microsoftAuth) {
    _googleAuth.addListener(_notify);
    _microsoftAuth.addListener(_notify);
  }

  final GoogleAuthService _googleAuth;
  final MicrosoftAuthService _microsoftAuth;
  bool _initialized = false;

  bool get isLoading => _googleAuth.isChecking || _microsoftAuth.isChecking;
  bool get isSignedIn => _googleAuth.isSignedIn || _microsoftAuth.isSignedIn;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([
      _googleAuth.initSilently(),
      _microsoftAuth.initSilently(),
    ]);
  }

  void _notify() => notifyListeners();

  @override
  void dispose() {
    _googleAuth.removeListener(_notify);
    _microsoftAuth.removeListener(_notify);
    super.dispose();
  }
}
