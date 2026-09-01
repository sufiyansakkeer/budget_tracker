import '../entities/app_settings.dart';
import '../entities/color_palette_entity.dart';
import '../entities/notification_settings.dart';
import '../entities/theme_mode_entity.dart';

/// Contract for persisting and reading application settings.
abstract class SettingsRepository {
  /// Loads the full settings snapshot from persistent storage.
  Future<AppSettings> loadSettings();

  /// Persists the theme mode.
  Future<void> setThemeMode(AppThemeMode mode);

  /// Persists the selected color palette.
  Future<void> setPalette(ColorPalette palette);

  /// Persists the selected currency code.
  Future<void> setCurrency(String code, String symbol);

  /// Persists notification preferences.
  Future<void> setNotificationSettings(NotificationSettings settings);

  /// Persists the biometric lock preference.
  Future<void> setBiometricEnabled(bool enabled);

  /// Marks the first-launch onboarding as completed.
  Future<void> setFirstLaunchCompleted();
}
