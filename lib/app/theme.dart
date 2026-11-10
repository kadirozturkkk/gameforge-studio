import 'package:flutter/material.dart';

/// Professional dark "engine" palette.
class GfColors {
  GfColors._();

  static const background = Color(0xFF1B1C1F);
  static const panel = Color(0xFF232428);
  static const panelHeader = Color(0xFF2A2B30);
  static const surface = Color(0xFF2E3036);
  static const border = Color(0xFF3A3C42);
  static const text = Color(0xFFE3E4E8);
  static const textMuted = Color(0xFF9A9CA5);
  static const accent = Color(0xFF4C8DFF);
  static const accentOrange = Color(0xFFFF8A3D);
  static const selection = Color(0xFF3D6FD1);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF46A758);
  static const viewport = Color(0xFF15161A);
  static const gridMinor = Color(0x18FFFFFF);
  static const gridMajor = Color(0x30FFFFFF);
}

ThemeData buildGfTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: GfColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: GfColors.accent,
    secondary: GfColors.accentOrange,
    surface: GfColors.panel,
    error: GfColors.danger,
    onSurface: GfColors.text,
    outline: GfColors.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.compact,
  );
  const borderSide = BorderSide(color: GfColors.border);
  return base.copyWith(
    scaffoldBackgroundColor: GfColors.background,
    canvasColor: GfColors.panel,
    dividerColor: GfColors.border,
    dividerTheme: const DividerThemeData(color: GfColors.border, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: GfColors.panelHeader,
      foregroundColor: GfColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GfColors.text),
      shape: Border(bottom: borderSide),
    ),
    cardTheme: CardThemeData(
      color: GfColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderSide,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GfColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: borderSide,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: GfColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: borderSide),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: borderSide),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: GfColors.accent)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: GfColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderSide,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: GfColors.surface,
      contentTextStyle: TextStyle(color: GfColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: GfColors.surface),
      textStyle: TextStyle(color: GfColors.text, fontSize: 12),
    ),
  );
}
