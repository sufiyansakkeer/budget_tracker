import 'package:flutter/material.dart';
import '../di/injection.dart' as di;
import '../../features/settings/domain/entities/app_settings.dart';
import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/entities/theme_mode_entity.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';

/// Provider that manages theme mode based on user settings.
class ThemeProvider extends ChangeNotifier {
  final LoadSettingsUseCase _loadSettingsUseCase;
  AppThemeMode _themeMode = AppThemeMode.system;

  ThemeProvider({LoadSettingsUseCase? loadSettingsUseCase})
    : _loadSettingsUseCase =
          loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>() {
    _loadThemeMode();
  }

  AppThemeMode get themeMode => _themeMode;

  ThemeMode get flutterThemeMode => _themeMode.toThemeMode();

  Future<void> _loadThemeMode() async {
    try {
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        _themeMode = (data as AppSettings).themeMode;
        notifyListeners();
      }
    } catch (e) {
      // Keep default theme mode on error
    }
  }

  void updateThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
