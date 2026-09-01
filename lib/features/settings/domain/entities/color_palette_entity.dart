import 'package:equatable/equatable.dart';

/// Available color palettes for the application.
///
/// Each palette has a distinct visual identity. The user selects a palette,
/// and the active ThemeMode (Light / Dark / System) determines which variant
/// is displayed.
enum ColorPalette {
  defaultPalette,
  ocean,
  forest,
  sunset,
  violet,
  rose;

  /// Parses a persisted string back to a [ColorPalette].
  static ColorPalette fromString(String? value) {
    return ColorPalette.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ColorPalette.defaultPalette,
    );
  }
}

/// Display metadata for a palette shown in the selection UI.
class PaletteOption extends Equatable {
  final ColorPalette palette;
  final String label;
  final String description;

  const PaletteOption({
    required this.palette,
    required this.label,
    required this.description,
  });

  @override
  List<Object?> get props => [palette, label, description];
}

/// The list of palette options presented to the user.
const List<PaletteOption> paletteOptions = [
  PaletteOption(
    palette: ColorPalette.defaultPalette,
    label: 'Default',
    description: 'Classic blue & teal',
  ),
  PaletteOption(
    palette: ColorPalette.ocean,
    label: 'Ocean',
    description: 'Deep blue & aqua',
  ),
  PaletteOption(
    palette: ColorPalette.forest,
    label: 'Forest',
    description: 'Emerald green & sage',
  ),
  PaletteOption(
    palette: ColorPalette.sunset,
    label: 'Sunset',
    description: 'Warm amber & coral',
  ),
  PaletteOption(
    palette: ColorPalette.violet,
    label: 'Violet',
    description: 'Rich purple & lavender',
  ),
  PaletteOption(
    palette: ColorPalette.rose,
    label: 'Rose',
    description: 'Blush pink & mauve',
  ),
];
