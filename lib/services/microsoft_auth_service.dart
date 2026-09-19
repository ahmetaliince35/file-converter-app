import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MicrosoftAuthService extends ChangeNotifier {
  static const String _clientId = 'aba92ff3-7185-4903-b805-a9d1df36b72f';

  late final AadOAuth _oauth;
  String? _accessToken;
  String? _userEmail;
  bool _isChecking = true;

  bool get isSignedIn => _accessToken != null;
  bool get isChecking => _isChecking;
  String? get userEmail => _userEmail;
  String? get accessToken => _accessToken;

  MicrosoftAuthService() {
    final Config config = Config(
      tenant: 'common',
      clientId: _clientId,
      scope: 'openid profile offline_access Files.ReadWrite User.Read',
      redirectUri: 'https://login.microsoftonline.com/common/oauth2/nativeclient',
      navigatorKey: appNavigatorKey,
    );
    _oauth = AadOAuth(config);
  }

  /// Açılışta kayıtlı token varsa sessizce alır
  Future<void> initSilently() async {
    try {
      final hasToken = await _oauth.hasCachedAccountInformation;
      if (hasToken) {
        _accessToken = await _oauth.getAccessToken();
        if (_accessToken != null) {
          _userEmail = 'Microsoft Hesabı';
        }
      }
    } catch (e) {
      debugPrint('Microsoft sessiz kontrol hatası: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> signIn() async {
    try {
      await _oauth.login();
      _accessToken = await _oauth.getAccessToken();

      if (_accessToken != null) {
        _userEmail = 'Microsoft Hesabı';
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Microsoft Giriş Hatası: $e');
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    _accessToken ??= await _oauth.getAccessToken();
    return _accessToken;
  }

  Future<void> signOut() async {
    try {
      await _oauth.logout();
    } catch (_) {}
    _accessToken = null;
    _userEmail = null;
    notifyListeners();
  }
}