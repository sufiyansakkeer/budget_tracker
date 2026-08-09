import 'package:equatable/equatable.dart';

import '../../../domain/entities/theme_mode_entity.dart';

/// Base class for all theme events.
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

/// Emitted when the app starts to restore the persisted theme preference.
class ThemeLoadRequested extends ThemeEvent {
  const ThemeLoadRequested();
}

/// Emitted when the user selects a new theme mode.
class ThemeChanged extends ThemeEvent {
  final AppThemeMode mode;

  const ThemeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}
