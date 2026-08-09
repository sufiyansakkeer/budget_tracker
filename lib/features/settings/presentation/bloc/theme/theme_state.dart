import 'package:equatable/equatable.dart';

import '../../../domain/entities/theme_mode_entity.dart';

/// Immutable state holding the current application theme mode.
class ThemeState extends Equatable {
  final AppThemeMode mode;

  const ThemeState({this.mode = AppThemeMode.system});

  ThemeState copyWith({AppThemeMode? mode}) {
    return ThemeState(mode: mode ?? this.mode);
  }

  @override
  List<Object?> get props => [mode];
}
