import 'package:equatable/equatable.dart';

import '../../../domain/entities/color_palette_entity.dart';
import '../../../domain/entities/theme_mode_entity.dart';

/// Immutable state holding the current application theme mode and color palette.
class ThemeState extends Equatable {
  final AppThemeMode mode;
  final ColorPalette palette;

  const ThemeState({
    this.mode = AppThemeMode.system,
    this.palette = ColorPalette.defaultPalette,
  });

  ThemeState copyWith({AppThemeMode? mode, ColorPalette? palette}) {
    return ThemeState(
      mode: mode ?? this.mode,
      palette: palette ?? this.palette,
    );
  }

  @override
  List<Object?> get props => [mode, palette];
}
