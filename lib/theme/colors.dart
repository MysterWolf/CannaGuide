import 'package:flutter/material.dart';

abstract final class C {
  static const bg = Color(0xFFFAF7F0);
  static const surface = Color(0xFFF2EDE4);
  static const border = Color(0xFFE2D9CC);
  static const text = Color(0xFF2C1A08);
  static const muted = Color(0xFF8A7A6A);
  static const light = Color(0xFFB8A898);

  static const accent = Color(0xFF8B6B47);
  static const accentLight = Color(0xFFF5EDE3);

  static const gold = Color(0xFFD4A853);
  static const goldLight = Color(0xFFFAF0DC);

  static const sage = Color(0xFF6B8F71);
  static const sageLt = Color(0xFFD4E6D6);

  static const amber = Color(0xFFC4883A);
  static const amberLt = Color(0xFFF5E6CC);

  static const danger = Color(0xFFB85450);
  static const dangerLt = Color(0xFFF0DDDB);

  static const purple = Color(0xFF7F77DD);
  static const purpleLt = Color(0xFFEEEDFE);
  static const purpleMid = Color(0xFF534AB7);

  static const blue = Color(0xFF378ADD);
  static const blueLt = Color(0xFFE6F1FB);

  static const circles = Color(0xFF5A7AB8);
  static const circlesLt = Color(0xFFEDF1FA);

  static const white = Color(0xFFFFFFFF);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.light(
      primary: C.accent,
      onPrimary: C.white,
      secondary: C.gold,
      onSecondary: C.text,
      surface: C.surface,
      onSurface: C.text,
      outline: C.border,
      error: C.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: C.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: C.border),
      ),
    ),
    dividerColor: C.border,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: C.text, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: C.text, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: C.text, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: C.text, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: C.text),
      bodyMedium: TextStyle(color: C.text),
      bodySmall: TextStyle(color: C.muted),
      labelSmall: TextStyle(color: C.muted),
    ),
  );
}
