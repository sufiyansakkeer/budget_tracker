import 'package:equatable/equatable.dart';

/// Available color palettes for the application.
///
/// Each palette has a distinct visual identity. The user selects a palette,
/// and the active ThemeMode (Light / Dark / System) determines which variant
/// is displayed.
enum ColorPalette {
  defaultPalette,
  ocean,
  blossomVapor,
  mahoganyBlaze,
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
    description: 'Indigo & teal',
  ),
  PaletteOption(
    palette: ColorPalette.blossomVapor,
    label: 'Blossom Vapor',
    description: 'Orchid & lavender',
  ),
  PaletteOption(
    palette: ColorPalette.mahoganyBlaze,
    label: 'Mahogany Blaze',
    description: 'Sienna & slate blue',
  ),
  PaletteOption(
    palette: ColorPalette.ocean,
    label: 'Ocean',
    description: 'Deep blue & coral',
  ),
  PaletteOption(
    palette: ColorPalette.forest,
    label: 'Forest',
    description: 'Evergreen & clay',
  ),
  PaletteOption(
    palette: ColorPalette.sunset,
    label: 'Sunset',
    description: 'Orange & amber',
  ),
  PaletteOption(
    palette: ColorPalette.violet,
    label: 'Violet',
    description: 'Violet & champagne',
  ),
  PaletteOption(
    palette: ColorPalette.rose,
    label: 'Rose',
    description: 'Deep rose & teal',
  ),
];
