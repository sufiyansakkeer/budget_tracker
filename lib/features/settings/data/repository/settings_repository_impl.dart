import '../../domain/entities/app_settings.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/theme_mode_entity.dart';
import '../../domain/repository/settings_repository.dart';
import '../datasource/settings_local_datasource.dart';

/// Concrete [SettingsRepository] backed by [SettingsLocalDataSource].
class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl({required this.localDataSource});

  @override
  Future<AppSettings> loadSettings() => localDataSource.loadSettings();

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      localDataSource.setThemeMode(mode);

  @override
  Future<void> setCurrency(String code, String symbol) =>
      localDataSource.setCurrency(code, symbol);

  @override
  Future<void> setNotificationSettings(NotificationSettings settings) =>
      localDataSource.setNotificationSettings(settings);

  @override
  Future<void> setBiometricEnabled(bool enabled) =>
      localDataSource.setBiometricEnabled(enabled);

  @override
  Future<void> setFirstLaunchCompleted() =>
      localDataSource.setFirstLaunchCompleted();
}
