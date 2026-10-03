import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimal, sade, göz yormayan, doğal ve düşük kontrastlı tema sistemi.
/// Not: Turkuaz/camgöbeği renkler kaldırılmış; dengeli arduvaz, grafit ve sakin indigo tonları seçilmiştir.
abstract final class AppTheme {
  // Marka & Vurgu Renkleri (Sade, minimal, sakin indigo/arduvaz tonları)
  static const primarySeed = Color(0xFF4F46E5); // Muted Indigo
  static const primaryLight = Color(0xFF6366F1); // Koyu mod için sakin, dengeli indigo

  // Açık Tema Renkleri (Sıcak keten, gözü yakmayan mat yüzeyler)
  static const _lightBg = Color(0xFFF7F6F3); // Sıcak ve yumuşak keten zemin
  static const _lightSurface = Color(0xFFFFFFFF); // Kartlar için saf beyaz
  static const _lightSurfaceSubtle = Color(0xFFEFECE6); // Arama kutusu ve hafif arka planlar
  static const _lightBorder = Color(0xFFE2DFD7); // Çok yumuşak, doğal sınır çizgisi
  static const _lightTextPrimary = Color(0xFF1E2024); // Yumuşak grafit siyah
  static const _lightTextSecondary = Color(0xFF6E7380); // Dengeli kurşun gri

  // Koyu Tema Renkleri (Düşük kontrastlı, gözü yormayan kömür / koyu arduvaz tonları - zıtlık ve parlamayı önler)
  static const _darkBg = Color(0xFF131417); // Yumuşak koyu kömür zemin (zifiri siyah değil)
  static const _darkSurface = Color(0xFF1C1D22); // Kartlar için yükseltilmiş mat yüzey
  static const _darkSurfaceSubtle = Color(0xFF24262E); // Çipler, ikincil kutular
  static const _darkSurfaceHigh = Color(0xFF2B2D37); // Vurgulu kartlar ve diyaloglar
  static const _darkBorder = Color(0xFF2C2E38); // Düşük kontrastlı, sakin sınır çizgisi
  static const _darkTextPrimary = Color(0xFFE4E4E7); // Yumuşak kırık inci beyazı (gözü almaz)
  static const _darkTextSecondary = Color(0xFF8E92A2); // Okunabilir, sakin ikincil metin

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primarySeed,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEEF0FC),
      onPrimaryContainer: Color(0xFF252859),
      secondary: Color(0xFF525866),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEFECE6),
      onSecondaryContainer: Color(0xFF2C3038),
      tertiary: Color(0xFF475569), // Slate (turkuaz yerine nötr arduvaz)
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE2E8F0),
      onTertiaryContainer: Color(0xFF1E293B),
      error: Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF991B1B),
      surface: _lightSurface,
      onSurface: _lightTextPrimary,
      onSurfaceVariant: _lightTextSecondary,
      surfaceDim: Color(0xFFEBE8E1),
      surfaceBright: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: _lightSurface,
      surfaceContainer: _lightSurfaceSubtle,
      surfaceContainerHigh: Color(0xFFE6E3DA),
      surfaceContainerHighest: Color(0xFFDDD9CF),
      outline: _lightTextSecondary,
      outlineVariant: _lightBorder,
      surfaceTint: Colors.transparent,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBg: _lightBg,
      cardBg: _lightSurface,
      borderColor: _lightBorder,
      systemOverlay: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF282B46),
      onPrimaryContainer: Color(0xFFE0E2FD),
      secondary: Color(0xFF9094A6),
      onSecondary: Color(0xFF131417),
      secondaryContainer: Color(0xFF24262E),
      onSecondaryContainer: Color(0xFFE2E5F0),
      tertiary: Color(0xFF64748B), // Muted Slate (asla turkuaz değil)
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF1E2230),
      onTertiaryContainer: Color(0xFFCBD5E1),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF381616),
      onErrorContainer: Color(0xFFFECACA),
      surface: _darkSurface,
      onSurface: _darkTextPrimary,
      onSurfaceVariant: _darkTextSecondary,
      surfaceDim: Color(0xFF131417),
      surfaceBright: Color(0xFF24262E),
      surfaceContainerLowest: Color(0xFF101114),
      surfaceContainerLow: _darkSurface,
      surfaceContainer: _darkSurfaceSubtle,
      surfaceContainerHigh: _darkSurfaceHigh,
      surfaceContainerHighest: Color(0xFF333644),
      outline: Color(0xFF828698),
      outlineVariant: _darkBorder,
      surfaceTint: Colors.transparent,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBg: _darkBg,
      cardBg: _darkSurface,
      borderColor: _darkBorder,
      systemOverlay: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color cardBg,
    required Color borderColor,
    required SystemUiOverlayStyle systemOverlay,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      canvasColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1D22) : Colors.white,
        hintStyle: TextStyle(fontSize: 13, color: colorScheme.outline),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E2028) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1D22) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF24262E) : const Color(0xFFEFECE6),
        side: BorderSide(color: borderColor.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
