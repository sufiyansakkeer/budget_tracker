import '../../domain/entities/app_settings.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/theme_mode_entity.dart';

/// Local data access for settings persistence.
abstract class SettingsLocalDataSource {
  Future<AppSettings> loadSettings();

  Future<void> setThemeMode(AppThemeMode mode);

  Future<void> setCurrency(String code, String symbol);

  Future<void> setNotificationSettings(NotificationSettings settings);

  Future<void> setBiometricEnabled(bool enabled);

  Future<void> setFirstLaunchCompleted();
}
