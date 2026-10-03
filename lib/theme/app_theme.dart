import 'package:flutter/material.dart';

/// Design tokens for DP Deeprows Player.
class DP {
  static const bg = Color(0xFF0C0E14);
  static const panel = Color(0xFF12151E);
  static const raised = Color(0xFF1B2030);
  static const line = Color(0xFF262C3D);
  static const text = Color(0xFFECEEF5);
  static const muted = Color(0xFF8A92A8);
  static const accent = Color(0xFF8B7BFF);
  static const onAccent = Color(0xFF14102E);
  static const live = Color(0xFFFF5470);

  static const double radius = 14;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: DP.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: DP.accent,
    onPrimary: DP.onAccent,
    surface: DP.panel,
    onSurface: DP.text,
    surfaceContainerHighest: DP.raised,
    outline: DP.line,
    error: DP.live,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: DP.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: DP.text, displayColor: DP.text),
    dividerTheme: const DividerThemeData(color: DP.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DP.raised,
      hintStyle: const TextStyle(color: DP.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DP.radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DP.radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DP.radius),
        borderSide: const BorderSide(color: DP.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DP.accent,
        foregroundColor: DP.onAccent,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DP.text,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: DP.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DP.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DP.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DP.line),
      ),
      titleTextStyle: const TextStyle(
        color: DP.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: DP.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: DP.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DP.raised,
      contentTextStyle: const TextStyle(color: DP.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: DP.line),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: DP.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DP.line),
      ),
      textStyle: const TextStyle(color: DP.text, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: DP.panel,
      surfaceTintColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(4),
      thumbColor: WidgetStateProperty.all(DP.line),
    ),
  );
}
