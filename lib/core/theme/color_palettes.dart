import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/color_palette_entity.dart';

/// Defines a complete light + dark color scheme pair for a palette.
///
/// Each palette provides a fully fleshed-out [ColorScheme] for both brightness
/// values, plus semantic colors for financial app concepts (income, expense,
/// etc.).
class PaletteColors {
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;

  // Semantic colors — light
  final Color incomeLight;
  final Color expenseLight;
  final Color successLight;
  final Color warningLight;
  final Color infoLight;
  final Color primaryGradientStartLight;
  final Color primaryGradientEndLight;

  // Semantic colors — dark
  final Color incomeDark;
  final Color expenseDark;
  final Color successDark;
  final Color warningDark;
  final Color infoDark;
  final Color primaryGradientStartDark;
  final Color primaryGradientEndDark;

  const PaletteColors({
    required this.lightScheme,
    required this.darkScheme,
    required this.incomeLight,
    required this.expenseLight,
    required this.successLight,
    required this.warningLight,
    required this.infoLight,
    required this.primaryGradientStartLight,
    required this.primaryGradientEndLight,
    required this.incomeDark,
    required this.expenseDark,
    required this.successDark,
    required this.warningDark,
    required this.infoDark,
    required this.primaryGradientStartDark,
    required this.primaryGradientEndDark,
  });

  /// Returns the semantic color for a given brightness.
  Color income(Brightness b) => b == Brightness.light ? incomeLight : incomeDark;
  Color expense(Brightness b) =>
      b == Brightness.light ? expenseLight : expenseDark;
  Color success(Brightness b) =>
      b == Brightness.light ? successLight : successDark;
  Color warning(Brightness b) =>
      b == Brightness.light ? warningLight : warningDark;
  Color info(Brightness b) => b == Brightness.light ? infoLight : infoDark;
  Color primaryGradientStart(Brightness b) =>
      b == Brightness.light ? primaryGradientStartLight : primaryGradientStartDark;
  Color primaryGradientEnd(Brightness b) =>
      b == Brightness.light ? primaryGradientEndLight : primaryGradientEndDark;
}

/// Retrieves the full [PaletteColors] for a given [ColorPalette].
PaletteColors getPaletteColors(ColorPalette palette) {
  switch (palette) {
    case ColorPalette.defaultPalette:
      return _defaultPalette;
    case ColorPalette.ocean:
      return _oceanPalette;
    case ColorPalette.forest:
      return _forestPalette;
    case ColorPalette.sunset:
      return _sunsetPalette;
    case ColorPalette.violet:
      return _violetPalette;
    case ColorPalette.rose:
      return _rosePalette;
  }
}

// =============================================================================
// Default Palette  (preserves the existing app look)
// =============================================================================

final PaletteColors _defaultPalette = PaletteColors(
  lightScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF3155D4),
    brightness: Brightness.light,
    primary: const Color(0xFF3155D4),
    secondary: const Color(0xFF159A9C),
    error: const Color(0xFFD65C62),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF182033),
  ),
  darkScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4C6FE3),
    brightness: Brightness.dark,
    primary: const Color(0xFF4C6FE3),
    secondary: const Color(0xFF31B6B5),
    error: const Color(0xFFE4777C),
    surface: const Color(0xFF11172A),
    onSurface: const Color(0xFFF4F7FF),
  ),
  incomeLight: const Color(0xFF239B70),
  expenseLight: const Color(0xFFD65C62),
  successLight: const Color(0xFF239B70),
  warningLight: const Color(0xFFD89432),
  infoLight: const Color(0xFF4A8CC7),
  primaryGradientStartLight: const Color(0xFF2543AD),
  primaryGradientEndLight: const Color(0xFF4C6FE3),
  incomeDark: const Color(0xFF43B98B),
  expenseDark: const Color(0xFFE4777C),
  successDark: const Color(0xFF43B98B),
  warningDark: const Color(0xFFE9AA50),
  infoDark: const Color(0xFF6AADE0),
  primaryGradientStartDark: const Color(0xFF3B5AD0),
  primaryGradientEndDark: const Color(0xFF5E80F0),
);

// =============================================================================
// Ocean Palette
// =============================================================================

final PaletteColors _oceanPalette = PaletteColors(
  lightScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0077B6),
    brightness: Brightness.light,
    primary: const Color(0xFF0077B6),
    secondary: const Color(0xFF00B4D8),
    tertiary: const Color(0xFF48CAE4),
    error: const Color(0xFFD65C62),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF0A2540),
  ),
  darkScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF48CAE4),
    brightness: Brightness.dark,
    primary: const Color(0xFF48CAE4),
    secondary: const Color(0xFF00B4D8),
    tertiary: const Color(0xFF90E0EF),
    error: const Color(0xFFE4777C),
    surface: const Color(0xFF0A1628),
    onSurface: const Color(0xFFE8F4F8),
  ),
  incomeLight: const Color(0xFF06D6A0),
  expenseLight: const Color(0xFFEF476F),
  successLight: const Color(0xFF06D6A0),
  warningLight: const Color(0xFFFFD166),
  infoLight: const Color(0xFF118AB2),
  primaryGradientStartLight: const Color(0xFF023E8A),
  primaryGradientEndLight: const Color(0xFF0077B6),
  incomeDark: const Color(0xFF52E0B0),
  expenseDark: const Color(0xFFF06E8E),
  successDark: const Color(0xFF52E0B0),
  warningDark: const Color(0xFFFFD88A),
  infoDark: const Color(0xFF48B0D4),
  primaryGradientStartDark: const Color(0xFF0353A4),
  primaryGradientEndDark: const Color(0xFF0096C7),
);

// =============================================================================
// Forest Palette
// =============================================================================

final PaletteColors _forestPalette = PaletteColors(
  lightScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2D6A4F),
    brightness: Brightness.light,
    primary: const Color(0xFF2D6A4F),
    secondary: const Color(0xFF52B788),
    tertiary: const Color(0xFF74C69D),
    error: const Color(0xFFD65C62),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF1B2E1B),
  ),
  darkScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF52B788),
    brightness: Brightness.dark,
    primary: const Color(0xFF52B788),
    secondary: const Color(0xFF74C69D),
    tertiary: const Color(0xFF95D5B2),
    error: const Color(0xFFE4777C),
    surface: const Color(0xFF0C1A0F),
    onSurface: const Color(0xFFE8F5E9),
  ),
  incomeLight: const Color(0xFF2D6A4F),
  expenseLight: const Color(0xFFE07A5F),
  successLight: const Color(0xFF40916C),
  warningLight: const Color(0xFFD4A373),
  infoLight: const Color(0xFF468FAF),
  primaryGradientStartLight: const Color(0xFF1B4332),
  primaryGradientEndLight: const Color(0xFF2D6A4F),
  incomeDark: const Color(0xFF74C69D),
  expenseDark: const Color(0xFFF09E87),
  successDark: const Color(0xFF74C69D),
  warningDark: const Color(0xFFE0B98F),
  infoDark: const Color(0xFF6DB0D0),
  primaryGradientStartDark: const Color(0xFF2D6A4F),
  primaryGradientEndDark: const Color(0xFF52B788),
);

// =============================================================================
// Sunset Palette
// =============================================================================

final PaletteColors _sunsetPalette = PaletteColors(
  lightScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFE85D04),
    brightness: Brightness.light,
    primary: const Color(0xFFE85D04),
    secondary: const Color(0xFFDC2F02),
    tertiary: const Color(0xFFFFBA08),
    error: const Color(0xFFD65C62),
    surface: const Color(0xFFFFFBF5),
    onSurface: const Color(0xFF3D1C02),
  ),
  darkScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFFCBF49),
    brightness: Brightness.dark,
    primary: const Color(0xFFFCBF49),
    secondary: const Color(0xFFF48C06),
    tertiary: const Color(0xFFFFBA08),
    error: const Color(0xFFE4777C),
    surface: const Color(0xFF1A0F05),
    onSurface: const Color(0xFFFFF3E0),
  ),
  incomeLight: const Color(0xFF06D6A0),
  expenseLight: const Color(0xFFDC2F02),
  successLight: const Color(0xFF06D6A0),
  warningLight: const Color(0xFFE85D04),
  infoLight: const Color(0xFF468FAF),
  primaryGradientStartLight: const Color(0xFFDC2F02),
  primaryGradientEndLight: const Color(0xFFE85D04),
  incomeDark: const Color(0xFF52E0B0),
  expenseDark: const Color(0xFFEF5350),
  successDark: const Color(0xFF52E0B0),
  warningDark: const Color(0xFFFFB74D),
  infoDark: const Color(0xFF6DB0D0),
  primaryGradientStartDark: const Color(0xFFE85D04),
  primaryGradientEndDark: const Color(0xFFFCBF49),
);

// =============================================================================
// Violet Palette
// =============================================================================

final PaletteColors _violetPalette = PaletteColors(
  lightScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B2CBF),
    brightness: Brightness.light,
    primary: const Color(0xFF7B2CBF),
    secondary: const Color(0xFFC77DFF),
    tertiary: const Color(0xFF9D4EDD),
    error: const Color(0xFFD65C62),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF1A0A2E),
  ),
  darkScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC77DFF),
    brightness: Brightness.dark,
    primary: const Color(0xFFC77DFF),
    secondary: const Color(0xFF9D4EDD),
    tertiary: const Color(0xFFE0AAFF),
    error: const Color(0xFFE4777C),
    surface: const Color(0xFF100820),
    onSurface: const Color(0xFFF3E8FF),
  ),
  incomeLight: const Color(0xFF2D6A4F),
  expenseLight: const Color(0xFFE05285),
  successLight: const Color(0xFF40916C),
  warningLight: const Color(0xFFF4A261),
  infoLight: const Color(0xFF7B2CBF),
  primaryGradientStartLight: const Color(0xFF5A189A),
  primaryGradientEndLight: const Color(0xFF7B2CBF),
  incomeDark: const Color(0xFF74C69D),
  expenseDark: const Color(0xFFF07090),
  successDark: const Color(0xFF74C69D),
  warningDark: const Color(0xFFF4B878),
  infoDark: const Color(0xFFB87BEE),
  primaryGradientStartDark: const Color(0xFF9D4EDD),
  primaryGradientEndDark: const Color(0xFFC77DFF),
);

// =============================================================================
// Rose Palette
// =============================================================================

final PaletteColors _rosePalette = PaletteColors(
  lightScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC9184A),
    brightness: Brightness.light,
    primary: const Color(0xFFC9184A),
    secondary: const Color(0xFFFF4D6D),
    tertiary: const Color(0xFFFF758F),
    error: const Color(0xFFD65C62),
    surface: const Color(0xFFFFFBFC),
    onSurface: const Color(0xFF2B0A10),
  ),
  darkScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF758F),
    brightness: Brightness.dark,
    primary: const Color(0xFFFF758F),
    secondary: const Color(0xFFFF4D6D),
    tertiary: const Color(0xFFFFB3C1),
    error: const Color(0xFFE4777C),
    surface: const Color(0xFF180A10),
    onSurface: const Color(0xFFFFF0F3),
  ),
  incomeLight: const Color(0xFF2D6A4F),
  expenseLight: const Color(0xFFC9184A),
  successLight: const Color(0xFF40916C),
  warningLight: const Color(0xFFF4A261),
  infoLight: const Color(0xFF468FAF),
  primaryGradientStartLight: const Color(0xFFA4133C),
  primaryGradientEndLight: const Color(0xFFC9184A),
  incomeDark: const Color(0xFF74C69D),
  expenseDark: const Color(0xFFFF6B81),
  successDark: const Color(0xFF74C69D),
  warningDark: const Color(0xFFF4B878),
  infoDark: const Color(0xFF6DB0D0),
  primaryGradientStartDark: const Color(0xFFE43F6E),
  primaryGradientEndDark: const Color(0xFFFF758F),
);
