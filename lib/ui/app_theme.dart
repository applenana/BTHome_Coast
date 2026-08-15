import 'package:flutter/material.dart';

abstract final class SeaColors {
  static const deep = Color(0xff063b5c);
  static const ocean = Color(0xff087fa8);
  static const cyan = Color(0xff29b6df);
  static const foam = Color(0xffeaf8fd);
  static const sky = Color(0xfff5fbfe);
  static const ink = Color(0xff16394c);
  static const muted = Color(0xff668696);
  static const coral = Color(0xffff6f61);
  static const sand = Color(0xffffcf75);
}

ThemeData buildSeaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SeaColors.ocean,
    brightness: Brightness.light,
    primary: SeaColors.ocean,
    secondary: SeaColors.cyan,
    surface: Colors.white,
    error: SeaColors.coral,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SeaColors.sky,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: SeaColors.deep,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineSmall: TextStyle(
        color: SeaColors.deep,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(color: SeaColors.ink, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: SeaColors.ink, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: SeaColors.ink, height: 1.35),
      bodySmall: TextStyle(color: SeaColors.muted, height: 1.3),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.9),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SeaColors.foam.withValues(alpha: 0.75),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x1a087fa8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SeaColors.cyan, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SeaColors.deep,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
