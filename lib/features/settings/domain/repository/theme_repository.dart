import '../entities/theme_mode_entity.dart';
import 'settings_repository.dart';

/// Repository responsible for persisting and reading the application theme.
///
/// This is the single gateway between the theme BLoC and local storage. Widgets
/// never touch [SettingsRepository] or SharedPreferences directly for theme.
class ThemeRepository {
  final SettingsRepository _settingsRepository;

  ThemeRepository({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  /// Loads the currently persisted [AppThemeMode].
  Future<AppThemeMode> getTheme() async {
    final settings = await _settingsRepository.loadSettings();
    return settings.themeMode;
  }

  /// Persists the selected [AppThemeMode] locally.
  Future<void> saveTheme(AppThemeMode mode) async {
    await _settingsRepository.setThemeMode(mode);
  }
}
