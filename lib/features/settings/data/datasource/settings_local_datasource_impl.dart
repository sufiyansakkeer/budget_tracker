import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/color_palette_entity.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/theme_mode_entity.dart';
import 'settings_local_datasource.dart';
import '../../../../core/constants/preference_keys.dart';

/// Concrete [SettingsLocalDataSource] backed by the Drift [Settings] table and
/// SharedPreferences for the first-launch flag.
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  static const String _themeKey = 'themeMode';
  static const String _paletteKey = 'colorPalette';
  static const String _currencyCodeKey = 'currencyCode';
  static const String _currencySymbolKey = 'currencySymbol';
  static const String _biometricKey = 'biometricEnabled';

  final AppDatabase database;
  final SharedPreferences sharedPreferences;

  SettingsLocalDataSourceImpl({
    required this.database,
    required this.sharedPreferences,
  });

  Future<void> _set(String key, String value) async {
    await (database.into(
      database.settings,
    )).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  @override
  Future<AppSettings> loadSettings() async {
    // One query, not one per key. Settings are read on startup by the theme,
    // currency, settings and notification layers, so a per-key SELECT turned
    // into dozens of round-trips before the first frame.
    final rows = await database.select(database.settings).get();
    final values = {for (final row in rows) row.key: row.value};
    String? get(String key) => values[key];

    final theme = AppThemeMode.fromString(get(_themeKey));
    final palette = ColorPalette.fromString(get(_paletteKey));
    final currencyCode = get(_currencyCodeKey) ?? 'INR';
    final currency = currencyByCode(currencyCode);
    final notifications = NotificationSettings(
      notificationsEnabled: get('notificationsEnabled') != 'false',
      morningReminderEnabled: get('morningReminderEnabled') != 'false',
      morningReminderTime: NotificationTime.fromString(
        get('morningReminderTime'),
      ),
      eveningSummaryEnabled: get('eveningSummaryEnabled') != 'false',
      eveningSummaryTime: NotificationTime.fromString(
        get('eveningSummaryTime'),
      ),
      overspendingAlertsEnabled: get('overspendingAlertsEnabled') != 'false',
      dailyRemindersEnabled: get('dailyRemindersEnabled') != 'false',
      noExpenseReminderEnabled: get('noExpenseReminderEnabled') != 'false',
      quietHoursEnabled: get('quietHoursEnabled') == 'true',
      quietHoursStart: NotificationTime.fromString(get('quietHoursStart')),
      quietHoursEnd: NotificationTime.fromString(get('quietHoursEnd')),
    );
    final biometric = get(_biometricKey) == 'true';
    final firstLaunch =
        sharedPreferences.getBool(PreferenceKeys.isFirstLaunch) ?? true;

    return AppSettings(
      themeMode: theme,
      colorPalette: palette,
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
  Future<void> setPalette(ColorPalette palette) async {
    await _set(_paletteKey, palette.name);
  }

  @override
  Future<void> setCurrency(String code, String symbol) async {
    await _set(_currencyCodeKey, code);
    await _set(_currencySymbolKey, symbol);
  }

  @override
  Future<void> setNotificationSettings(NotificationSettings settings) async {
    // One batch instead of eleven sequential upserts.
    await database.batch((b) {
      b.insertAllOnConflictUpdate(database.settings, [
        for (final entry in <String, String>{
          'notificationsEnabled': settings.notificationsEnabled.toString(),
          'morningReminderEnabled': settings.morningReminderEnabled.toString(),
          'morningReminderTime': settings.morningReminderTime.toSettingString(),
          'eveningSummaryEnabled': settings.eveningSummaryEnabled.toString(),
          'eveningSummaryTime': settings.eveningSummaryTime.toSettingString(),
          'overspendingAlertsEnabled': settings.overspendingAlertsEnabled
              .toString(),
          'dailyRemindersEnabled': settings.dailyRemindersEnabled.toString(),
          'noExpenseReminderEnabled': settings.noExpenseReminderEnabled
              .toString(),
          'quietHoursEnabled': settings.quietHoursEnabled.toString(),
          'quietHoursStart': settings.quietHoursStart.toSettingString(),
          'quietHoursEnd': settings.quietHoursEnd.toSettingString(),
        }.entries)
          SettingsCompanion.insert(key: entry.key, value: entry.value),
      ]);
    });
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    await _set(_biometricKey, enabled.toString());
  }

  @override
  Future<void> setFirstLaunchCompleted() async {
    await sharedPreferences.setBool(PreferenceKeys.isFirstLaunch, false);
  }
}
