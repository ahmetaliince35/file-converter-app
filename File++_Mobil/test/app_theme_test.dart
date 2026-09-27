import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_converter/core/theme/app_theme.dart';

void main() {
  test('açık ve koyu tema Material 3 renk şeması üretir', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();

    expect(lightTheme.useMaterial3, isTrue);
    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
    expect(lightTheme.colorScheme.primary, isNot(darkTheme.colorScheme.primary));
  });
}
