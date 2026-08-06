import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/theme_mode_entity.dart';
import 'settings_local_datasource.dart';

/// Concrete [SettingsLocalDataSource] backed by the Drift [Settings] table and
/// SharedPreferences for the first-launch flag.
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  static const String _firstLaunchKey = 'isFirstLaunch';
  static const String _themeKey = 'themeMode';
  static const String _currencyCodeKey = 'currencyCode';
  static const String _currencySymbolKey = 'currencySymbol';
  static const String _biometricKey = 'biometricEnabled';

  final AppDatabase database;
  final SharedPreferences sharedPreferences;

  SettingsLocalDataSourceImpl({
    required this.database,
    required this.sharedPreferences,
  });

  Future<String?> _get(String key) async {
    final row = await (database.select(
      database.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) async {
    await (database.into(
      database.settings,
    )).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  @override
  Future<AppSettings> loadSettings() async {
    final theme = AppThemeMode.fromString(await _get(_themeKey));
    final currencyCode = await _get(_currencyCodeKey) ?? 'INR';
    final currency = currencyByCode(currencyCode);
    final notifications = NotificationSettings(
      notificationsEnabled: (await _get('notificationsEnabled')) != 'false',
      morningReminderEnabled: (await _get('morningReminderEnabled')) != 'false',
      morningReminderTime: NotificationTime.fromString(
        await _get('morningReminderTime'),
      ),
      eveningSummaryEnabled: (await _get('eveningSummaryEnabled')) != 'false',
      eveningSummaryTime: NotificationTime.fromString(
        await _get('eveningSummaryTime'),
      ),
      overspendingAlertsEnabled:
          (await _get('overspendingAlertsEnabled')) != 'false',
      dailyRemindersEnabled: (await _get('dailyRemindersEnabled')) != 'false',
      noExpenseReminderEnabled:
          (await _get('noExpenseReminderEnabled')) != 'false',
      quietHoursEnabled: (await _get('quietHoursEnabled')) == 'true',
      quietHoursStart: NotificationTime.fromString(
        await _get('quietHoursStart'),
      ),
      quietHoursEnd: NotificationTime.fromString(await _get('quietHoursEnd')),
    );
    final biometric = (await _get(_biometricKey)) == 'true';
    final firstLaunch = sharedPreferences.getBool(_firstLaunchKey) ?? true;

    return AppSettings(
      themeMode: theme,
      currencyCode: currency.code,
      currencySymbol: currency.symbol,
      notifications: notifications,
      biometricEnabled: biometric,
      firstLaunchCompleted: !firstLaunch,
    );
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _set(_themeKey, mode.name);
  }

  @override
  Future<void> setCurrency(String code, String symbol) async {
    await _set(_currencyCodeKey, code);
    await _set(_currencySymbolKey, symbol);
  }

  @override
  Future<void> setNotificationSettings(NotificationSettings settings) async {
    await _set(
      'notificationsEnabled',
      settings.notificationsEnabled.toString(),
    );
    await _set(
      'morningReminderEnabled',
      settings.morningReminderEnabled.toString(),
    );
    await _set(
      'morningReminderTime',
      settings.morningReminderTime.toSettingString(),
    );
    await _set(
      'eveningSummaryEnabled',
      settings.eveningSummaryEnabled.toString(),
    );
    await _set(
      'eveningSummaryTime',
      settings.eveningSummaryTime.toSettingString(),
    );
    await _set(
      'overspendingAlertsEnabled',
      settings.overspendingAlertsEnabled.toString(),
    );
    await _set(
      'dailyRemindersEnabled',
      settings.dailyRemindersEnabled.toString(),
    );
    await _set(
      'noExpenseReminderEnabled',
      settings.noExpenseReminderEnabled.toString(),
    );
    await _set('quietHoursEnabled', settings.quietHoursEnabled.toString());
    await _set('quietHoursStart', settings.quietHoursStart.toSettingString());
    await _set('quietHoursEnd', settings.quietHoursEnd.toSettingString());
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    await _set(_biometricKey, enabled.toString());
  }

  @override
  Future<void> setFirstLaunchCompleted() async {
    await sharedPreferences.setBool(_firstLaunchKey, false);
  }
}
