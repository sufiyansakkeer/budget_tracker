import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Application theme preference options.
enum AppThemeMode {
  system,
  light,
  dark;

  /// Converts to a Flutter [ThemeMode].
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Parses a persisted string back to an [AppThemeMode].
  static AppThemeMode fromString(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

/// Label + icon shown in the theme selector UI.
class ThemeOption extends Equatable {
  final AppThemeMode mode;
  final String label;
  final String description;
  final IconData icon;

  const ThemeOption({
    required this.mode,
    required this.label,
    required this.description,
    required this.icon,
  });

  @override
  List<Object?> get props => [mode, label, description, icon];
}

/// The list of theme options presented to the user.
const List<ThemeOption> themeOptions = [
  ThemeOption(
    mode: AppThemeMode.system,
    label: 'System',
    description: 'Follow device theme',
    icon: Icons.brightness_auto,
  ),
  ThemeOption(
    mode: AppThemeMode.light,
    label: 'Light',
    description: 'Always use light theme',
    icon: Icons.light_mode,
  ),
  ThemeOption(
    mode: AppThemeMode.dark,
    label: 'Dark',
    description: 'Always use dark theme',
    icon: Icons.dark_mode,
  ),
];
