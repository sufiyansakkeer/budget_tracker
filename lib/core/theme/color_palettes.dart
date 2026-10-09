import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/color_palette_entity.dart';

/// Defines a complete light + dark color scheme pair for a palette.
///
/// A palette owns the brand: primary, secondary and tertiary with their
/// containers, and the surface and ink they sit on. Error, money and status
/// colours (income, expense, success, warning, info) are shared by every
/// palette, so their meaning never changes with the brand.
///
/// Every value is written as it ships. Text accents already meet the floors
/// in `AppColorTokens` (4.5:1 on the deepest container), secondary and
/// tertiary 3:1 on the surface, and every "on" colour 4.5:1 on its fill, so
/// the contrast engine never has to rewrite a palette colour.
/// `test/core/theme/color_palette_test.dart` holds palettes to that.
///
/// Tonal rules, in HCT tone (0 black, 100 white):
/// * Light: primary near 40, containers near 90, and each container's "on"
///   colour is its accent's own hue near 36.
/// * Dark: accents near 72 to 80, containers near 28 at lower chroma, and
///   surfaces near-neutral (tone 6.5, chroma 4), so the palette shows in
///   accents and selection rather than in every card.
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
  Color income(Brightness b) =>
      b == Brightness.light ? incomeLight : incomeDark;
  Color expense(Brightness b) =>
      b == Brightness.light ? expenseLight : expenseDark;
  Color success(Brightness b) =>
      b == Brightness.light ? successLight : successDark;
  Color warning(Brightness b) =>
      b == Brightness.light ? warningLight : warningDark;
  Color info(Brightness b) => b == Brightness.light ? infoLight : infoDark;
  Color primaryGradientStart(Brightness b) => b == Brightness.light
      ? primaryGradientStartLight
      : primaryGradientStartDark;
  Color primaryGradientEnd(Brightness b) =>
      b == Brightness.light ? primaryGradientEndLight : primaryGradientEndDark;
}

/// Retrieves the full [PaletteColors] for a given [ColorPalette].
PaletteColors getPaletteColors(ColorPalette palette) {
  switch (palette) {
    case ColorPalette.defaultPalette:
      return _defaultPalette;
    case ColorPalette.blossomVapor:
      return _blossomVapor;
    case ColorPalette.mahoganyBlaze:
      return _mahoganyBlaze;
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
// Shared error, money and status families.
//
// These are meanings, not brand. A user who switches palette must still read
// "something went wrong", "over budget" and "paid" the same way, so every
// palette points at these constants. They keep Default's hues, set a touch
// deeper (light) or lighter (dark) than the contrast floor, so they pass AA
// on every palette's deepest container as written and ship identically
// everywhere.
//
// Gradients are the one per-palette extra: a short tonal sweep of the
// primary (about ±6 tones), never a second hue.
// =============================================================================
const Color _errorLight = Color(0xFFBC2D35);
const Color _onErrorLight = Color(0xFFFFFFFF);
const Color _errorContainerLight = Color(0xFFEED3D4);
const Color _onErrorContainerLight = Color(0xFFB22C33);

const Color _errorDark = Color(0xFFEA878B);
const Color _onErrorDark = Color(0xFF440E10);
const Color _errorContainerDark = Color(0xFF6E2B2E);
const Color _onErrorContainerDark = Color(0xFFEA9598);

const Color _incomeLight = Color(0xFF1E7249);
const Color _expenseLight = Color(0xFFB03E2A);
const Color _successLight = Color(0xFF1E724D);
const Color _warningLight = Color(0xFF8C591C);
const Color _infoLight = Color(0xFF296997);

const Color _incomeDark = Color(0xFF53C68C);
const Color _expenseDark = Color(0xFFDD8F82);
const Color _successDark = Color(0xFF5EC999);
const Color _warningDark = Color(0xFFDEB17C);
const Color _infoDark = Color(0xFF79ADD2);

// =============================================================================
// Default Palette  (indigo / teal / violet)
// =============================================================================
//
// The benchmark: indigo for action, teal and violet as quieter accents, on
// near-neutral surfaces with a slight cool bias. Its look is unchanged. The
// dark primary and the container "on" colours used to be written as one
// colour and shown as another (the contrast engine rewrote them); they are
// now written as the colours the app was already showing.

final PaletteColors _defaultPalette = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3155D4),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD1D8EF),
    onPrimaryContainer: Color(0xFF2E52D3),
    secondary: Color(0xFF159A9C),
    onSecondary: Color(0xFF002425),
    secondaryContainer: Color(0xFFCFF1F2),
    onSecondaryContainer: Color(0xFF107678),
    tertiary: Color(0xFF7B4DCB),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFDDD4ED),
    onTertiaryContainer: Color(0xFF7140C7),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF17191F),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF869DEC),
    onPrimary: Color(0xFF0B1947),
    primaryContainer: Color(0xFF283971),
    onPrimaryContainer: Color(0xFF8EA4ED),
    secondary: Color(0xFF31B6B5),
    onSecondary: Color(0xFF114040),
    secondaryContainer: Color(0xFF306969),
    onSecondaryContainer: Color(0xFFA4E7E6),
    tertiary: Color(0xFFB79FDF),
    onTertiary: Color(0xFF24143D),
    tertiaryContainer: Color(0xFF463267),
    onTertiaryContainer: Color(0xFFB79FDF),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF141418),
    onSurface: Color(0xFFF2F2F6),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF244ACA),
  primaryGradientEndLight: const Color(0xFF496AE9),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFF7188D5),
  primaryGradientEndDark: const Color(0xFF96ADFE),
);

// =============================================================================
// Ocean Palette  (deep ocean blue / muted cyan / soft coral)
// =============================================================================
//
// A deep, slightly green-leaning blue, clearly apart from Default's indigo,
// with a desaturated cyan beside it and coral as the one warm note.
// Surfaces carry a cool cast; the dark theme is graphite, not navy.

final PaletteColors _oceanPalette = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF005E93),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD4E1F1),
    onPrimaryContainer: Color(0xFF00598B),
    secondary: Color(0xFF3E7581),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCEE3E9),
    onSecondaryContainer: Color(0xFF235C67),
    tertiary: Color(0xFFC7725D),
    onTertiary: Color(0xFF370E05),
    tertiaryContainer: Color(0xFFF3D7D0),
    onTertiaryContainer: Color(0xFF883F2E),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFCFDFF),
    onSurface: Color(0xFF161C21),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF82BBF0),
    onPrimary: Color(0xFF002A46),
    primaryContainer: Color(0xFF26455F),
    onPrimaryContainer: Color(0xFFADD6FF),
    secondary: Color(0xFF8EC4D1),
    onSecondary: Color(0xFF002D34),
    secondaryContainer: Color(0xFF2B464D),
    onSecondaryContainer: Color(0xFFA4DAE8),
    tertiary: Color(0xFFFFAC99),
    onTertiary: Color(0xFF4D1406),
    tertiaryContainer: Color(0xFF5F382F),
    onTertiaryContainer: Color(0xFFFFC4B6),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF121517),
    onSurface: Color(0xFFEEEDEF),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF005484),
  primaryGradientEndLight: const Color(0xFF1B72AC),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFF6CA5D9),
  primaryGradientEndDark: const Color(0xFF96CCFF),
);

// =============================================================================
// Forest Palette  (evergreen / sage / clay)
// =============================================================================
//
// A deep, blue-leaning evergreen, darker and cooler than the shared
// success green so an "On track" chip never reads as a button. Sage is
// nearly grey on purpose; clay is the warm counterweight.

final PaletteColors _forestPalette = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1E574A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCEE5DC),
    onPrimaryContainer: Color(0xFF265E51),
    secondary: Color(0xFF64715A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD8E4CB),
    onSecondaryContainer: Color(0xFF4C5943),
    tertiary: Color(0xFF9D6444),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF2D8CB),
    onTertiaryContainer: Color(0xFF7B482A),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFCFDFC),
    onSurface: Color(0xFF181D18),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8FC7B6),
    onPrimary: Color(0xFF002E25),
    primaryContainer: Color(0xFF27483F),
    onPrimaryContainer: Color(0xFFA4DDCC),
    secondary: Color(0xFFB7C6AA),
    onSecondary: Color(0xFF1F2B18),
    secondaryContainer: Color(0xFF3C4536),
    onSecondaryContainer: Color(0xFFC8D6BA),
    tertiary: Color(0xFFF7B18C),
    onTertiary: Color(0xFF441D03),
    tertiaryContainer: Color(0xFF593B2B),
    onTertiaryContainer: Color(0xFFFFC5A7),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF131512),
    onSurface: Color(0xFFEEEEEA),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF114D41),
  primaryGradientEndLight: const Color(0xFF336A5D),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFF79B1A1),
  primaryGradientEndDark: const Color(0xFF9FD7C7),
);

// =============================================================================
// Sunset Palette  (burnt orange / terracotta / amber)
// =============================================================================
//
// An analogous warm run held at deep tones in light, so orange text stays
// readable. The amber is lighter and yellower than the shared warning
// bronze. The dark theme used to switch to yellow; both themes are now the
// same orange.

final PaletteColors _sunsetPalette = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF9F4700),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF2D8CB),
    onPrimaryContainer: Color(0xFF8C3E00),
    secondary: Color(0xFF9B5446),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF3D7D1),
    onSecondaryContainer: Color(0xFF844234),
    tertiary: Color(0xFFB98833),
    onTertiary: Color(0xFF281900),
    tertiaryContainer: Color(0xFFECDAC5),
    onTertiaryContainer: Color(0xFF734E00),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFFFDFA),
    onSurface: Color(0xFF221A14),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF9E65),
    onPrimary: Color(0xFF461B00),
    primaryContainer: Color(0xFF61381F),
    onPrimaryContainer: Color(0xFFFFC5A7),
    secondary: Color(0xFFFDA593),
    onSecondary: Color(0xFF4B160C),
    secondaryContainer: Color(0xFF5D3932),
    onSecondaryContainer: Color(0xFFFFC4B8),
    tertiary: Color(0xFFFBC367),
    onTertiary: Color(0xFF382400),
    tertiaryContainer: Color(0xFF533F1E),
    onTertiaryContainer: Color(0xFFFDC977),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF171412),
    onSurface: Color(0xFFF6ECE7),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF903F00),
  primaryGradientEndLight: const Color(0xFFBA5912),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFFEB8649),
  primaryGradientEndDark: const Color(0xFFFFB68E),
);

// =============================================================================
// Violet Palette  (violet / grey lavender / champagne gold)
// =============================================================================
//
// One rich violet, a lavender muted almost to grey, and champagne gold as a
// true complement. Three purples in a row used to make the palette loud;
// now only the primary is purple.

final PaletteColors _violetPalette = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6747A5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6DCF2),
    onPrimaryContainer: Color(0xFF62429F),
    secondary: Color(0xFF706A83),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE4DCF2),
    onSecondaryContainer: Color(0xFF57516A),
    tertiary: Color(0xFFA88648),
    onTertiary: Color(0xFF271900),
    tertiaryContainer: Color(0xFFEADBC5),
    onTertiaryContainer: Color(0xFF6C5017),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFDFCFF),
    onSurface: Color(0xFF1D1A22),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC4A7FE),
    onPrimary: Color(0xFF301A59),
    primaryContainer: Color(0xFF493B66),
    onPrimaryContainer: Color(0xFFDCC9FF),
    secondary: Color(0xFFCAC2DF),
    onSecondary: Color(0xFF29253B),
    secondaryContainer: Color(0xFF444051),
    onSecondaryContainer: Color(0xFFD6CDEB),
    tertiary: Color(0xFFF3CC87),
    onTertiary: Color(0xFF362500),
    tertiaryContainer: Color(0xFF504022),
    onTertiaryContainer: Color(0xFFF3CC87),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF151417),
    onSurface: Color(0xFFF1ECF0),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF5D3D9A),
  primaryGradientEndLight: const Color(0xFF7B5BBA),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFFAE92E7),
  primaryGradientEndDark: const Color(0xFFD3BBFF),
);

// =============================================================================
// Rose Palette  (deep rose / dusty pink / muted teal)
// =============================================================================
//
// A raspberry rose, deeper and bluer than the shared error crimson so errors
// still stand apart, with a dusty pink and a muted teal. The light page is
// a warm neutral, no longer pink.

final PaletteColors _rosePalette = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF96385C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF0D7DC),
    onPrimaryContainer: Color(0xFF903357),
    secondary: Color(0xFFA37B89),
    onSecondary: Color(0xFF2D131E),
    secondaryContainer: Color(0xFFEFD7DD),
    onSecondaryContainer: Color(0xFF6E4B58),
    tertiary: Color(0xFF43706C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCDE4E1),
    onTertiaryContainer: Color(0xFF2E5C58),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFFFCFC),
    onSurface: Color(0xFF22191D),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFB1C8),
    onPrimary: Color(0xFF4D102A),
    primaryContainer: Color(0xFF623443),
    onPrimaryContainer: Color(0xFFFFC1D2),
    secondary: Color(0xFFE8BBC9),
    onSecondary: Color(0xFF3C1F2B),
    secondaryContainer: Color(0xFF553B44),
    onSecondaryContainer: Color(0xFFF4C5D5),
    tertiary: Color(0xFF9BCAC5),
    onTertiary: Color(0xFF002E2B),
    tertiaryContainer: Color(0xFF2E4744),
    onTertiaryContainer: Color(0xFFABDBD5),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF171315),
    onSurface: Color(0xFFF5ECED),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF8A2E53),
  primaryGradientEndLight: const Color(0xFFAF4B70),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFFED98B2),
  primaryGradientEndDark: const Color(0xFFFFC9D8),
);

// =============================================================================
// Blossom Vapor Palette  (dusty orchid / lavender / mint)
// =============================================================================
//
// The softest palette: an orchid-leaning pink (cooler than Rose), with
// lavender and mint at mid tones carrying dark labels, so it stays pastel
// without turning neon. The light page is a warm neutral, no longer pink.

final PaletteColors _blossomVapor = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF844A7C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF2D8E9),
    onPrimaryContainer: Color(0xFF794072),
    secondary: Color(0xFF8782A7),
    onSecondary: Color(0xFF1B1736),
    secondaryContainer: Color(0xFFE2DDF3),
    onSecondaryContainer: Color(0xFF555173),
    tertiary: Color(0xFF6C9388),
    onTertiary: Color(0xFF002019),
    tertiaryContainer: Color(0xFFCEE5DC),
    onTertiaryContainer: Color(0xFF365C52),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFFFCFD),
    onSurface: Color(0xFF201A1F),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFEAAFDD),
    onPrimary: Color(0xFF451241),
    primaryContainer: Color(0xFF573851),
    onPrimaryContainer: Color(0xFFFCBFEE),
    secondary: Color(0xFFC8C2EA),
    onSecondary: Color(0xFF282443),
    secondaryContainer: Color(0xFF433F57),
    onSecondaryContainer: Color(0xFFD4CDF5),
    tertiary: Color(0xFFACD5C8),
    onTertiary: Color(0xFF032E25),
    tertiaryContainer: Color(0xFF324640),
    onTertiaryContainer: Color(0xFFB1DACD),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF171316),
    onSurface: Color(0xFFF4ECEF),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF794072),
  primaryGradientEndLight: const Color(0xFF9A5D91),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFFD299C7),
  primaryGradientEndDark: const Color(0xFFFCBFEE),
);

// =============================================================================
// Mahogany Blaze Palette  (burnt sienna / slate blue / antique gold)
// =============================================================================
//
// A deep red-brown sienna grounded by a slate blue complement, with antique
// gold. Deeper and browner than Sunset's orange so the two warm palettes
// stay apart.

final PaletteColors _mahoganyBlaze = PaletteColors(
  lightScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF883B22),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF3D7CF),
    onPrimaryContainer: Color(0xFF8B3E24),
    secondary: Color(0xFF566A7F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD4E1F1),
    onSecondaryContainer: Color(0xFF43576B),
    tertiary: Color(0xFFA7803A),
    onTertiary: Color(0xFF271900),
    tertiaryContainer: Color(0xFFEBDAC5),
    onTertiaryContainer: Color(0xFF704F0A),
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    surface: Color(0xFFFFFCFA),
    onSurface: Color(0xFF231914),
  ),
  darkScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF6AD96),
    onPrimary: Color(0xFF4D1502),
    primaryContainer: Color(0xFF633628),
    onPrimaryContainer: Color(0xFFFFC4B2),
    secondary: Color(0xFFA9BED5),
    onSecondary: Color(0xFF152A3C),
    secondaryContainer: Color(0xFF374350),
    onSecondaryContainer: Color(0xFFBFD4EB),
    tertiary: Color(0xFFEDBF72),
    onTertiary: Color(0xFF372400),
    tertiaryContainer: Color(0xFF523F1E),
    onTertiaryContainer: Color(0xFFF9CA7C),
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _onErrorContainerDark,
    surface: Color(0xFF181413),
    onSurface: Color(0xFFF6ECE8),
  ),
  incomeLight: _incomeLight,
  expenseLight: _expenseLight,
  successLight: _successLight,
  warningLight: _warningLight,
  infoLight: _infoLight,
  primaryGradientStartLight: const Color(0xFF7C3219),
  primaryGradientEndLight: const Color(0xFFA04E33),
  incomeDark: _incomeDark,
  expenseDark: _expenseDark,
  successDark: _successDark,
  warningDark: _warningDark,
  infoDark: _infoDark,
  primaryGradientStartDark: const Color(0xFFDE9781),
  primaryGradientEndDark: const Color(0xFFFFC0AD),
);
