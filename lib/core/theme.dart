import 'package:flutter/material.dart';

/// Rangi zinazofuata mockup ya MFUKO WA MAPATO YA KANISA.
class C {
  static const navy = Color(0xFF0B2E6B);
  static const navyDark = Color(0xFF071E4A);
  static const teal = Color(0xFF0E9F8A);
  static const gold = Color(0xFFE3A21A);
  static const blue = Color(0xFF1B6FD1);
  static const purple = Color(0xFF6B3FA0);
  static const bg = Color(0xFFF3F6FB);
  static const text = Color(0xFF0B2352);
  static const muted = Color(0xFF6B7A99);
  static const border = Color(0xFFDCE4F0);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.navy,
      primary: C.navy,
      secondary: C.teal,
    ),
    scaffoldBackgroundColor: C.bg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
