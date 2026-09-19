import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema tercihini saklar ve görünüm katmanına [ThemeMode] sunar.
class ThemeViewModel extends ChangeNotifier {
  static const _storageKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = preferences.getString(_storageKey);
    _themeMode = switch (storedValue) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> toggle() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
