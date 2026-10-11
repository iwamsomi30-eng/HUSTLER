import 'package:flutter/material.dart';

/// Professional visual palette inspired by the supplied reference screens.
/// Functional behavior, navigation, data and page structure are intentionally unchanged.
class C {
  // Primary brand: deep royal blue → electric blue → violet.
  static const navy = Color(0xFF062B73);
  static const navyDark = Color(0xFF031A4B);
  static const blue = Color(0xFF1478F6);
  static const blueBright = Color(0xFF1687FF);
  static const violet = Color(0xFF5B2CFF);

  // Supporting accents used by cards/statuses.
  static const teal = Color(0xFF11BFA4);
  static const cyan = Color(0xFF12B8D6);
  static const gold = Color(0xFFFFA914);
  static const purple = Color(0xFF7138F5);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF12B76A);

  // Neutral UI surfaces.
  static const bg = Color(0xFFF4F7FC);
  static const surface = Colors.white;
  static const text = Color(0xFF102A56);
  static const muted = Color(0xFF647A9E);
  static const border = Color(0xFFDCE6F3);

  static const sidebarStart = Color(0xFF062D78);
  static const sidebarEnd = Color(0xFF031A4B);
  static const topStart = Color(0xFF0759D8);
  static const topMid = Color(0xFF184EF1);
  static const topEnd = Color(0xFF5727E8);
  static const activeStart = Color(0xFF1688FF);
  static const activeEnd = Color(0xFF1268E8);
}

double pagePad(BuildContext c) => MediaQuery.sizeOf(c).width < 600 ? 12.0 : 20.0;
bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < 600;

double safeNum(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.blue,
      primary: C.blue,
      secondary: C.violet,
      surface: C.surface,
      error: C.red,
    ),
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    cardColor: C.surface,
    visualDensity: VisualDensity.standard,
    dividerColor: C.border,
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered)
              ? C.blue
              : const Color(0xFF7EA8E8)),
      trackColor: WidgetStateProperty.all(const Color(0xFFE8F0FB)),
      trackBorderColor: WidgetStateProperty.all(const Color(0xFFD1DFF2)),
      thickness: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged) ? 12.0 : 9.0),
      radius: const Radius.circular(8),
      interactive: true,
      minThumbLength: 48,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.blue,
      selectionColor: Color(0x331478F6),
      selectionHandleColor: C.blue,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.blue, width: 1.5),
      ),
      labelStyle: const TextStyle(color: C.muted),
      floatingLabelStyle: const TextStyle(color: C.blue),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.blue,
        side: const BorderSide(color: C.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.navyDark,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
