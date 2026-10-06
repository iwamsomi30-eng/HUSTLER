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

/// Pembezoni za ukurasa: ndogo kwenye simu ili maudhui yasibanwe.
double pagePad(BuildContext c) => MediaQuery.sizeOf(c).width < 600 ? 12.0 : 20.0;
bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < 600;

/// Kusoma namba kwa usalama (num au String) - inazuia jumla kuwa 0 kimakosa.
double safeNum(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
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
    canvasColor: C.bg,
    cardColor: Colors.white,
    visualDensity: VisualDensity.standard,
    dividerColor: C.border,
    // Scrollbar (hasa ya wima kwenye computer): bluu na nene ili ionekane na kutumika kirahisi.
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered)
              ? const Color(0xFF0B4FA8)
              : C.blue),
      trackColor: WidgetStateProperty.all(const Color(0xFFDCEBFF)),
      trackBorderColor: WidgetStateProperty.all(const Color(0xFFB9D4F7)),
      thickness: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged) ? 14.0 : 10.0),
      radius: const Radius.circular(8),
      interactive: true,
      minThumbLength: 48,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.teal,
      selectionColor: Color(0x3320A995),
      selectionHandleColor: C.teal,
    ),
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
