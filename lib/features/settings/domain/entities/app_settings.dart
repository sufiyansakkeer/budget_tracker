import 'package:equatable/equatable.dart';

import 'color_palette_entity.dart';
import 'currency_entity.dart';
import 'notification_settings.dart';
import 'theme_mode_entity.dart';

/// Immutable snapshot of all user-configurable application settings.
class AppSettings extends Equatable {
  final AppThemeMode themeMode;
  final ColorPalette colorPalette;
  final String currencyCode;
  final String currencySymbol;
  final NotificationSettings notifications;
  final bool biometricEnabled;
  final bool firstLaunchCompleted;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.colorPalette = ColorPalette.defaultPalette,
    this.currencyCode = 'INR',
    this.currencySymbol = '₹',
    this.notifications = const NotificationSettings(),
    this.biometricEnabled = false,
    this.firstLaunchCompleted = false,
  });

  /// Returns the currency details for the current code.
  CurrencyEntity get currency => currencyByCode(currencyCode);

  AppSettings copyWith({
    AppThemeMode? themeMode,
    ColorPalette? colorPalette,
    String? currencyCode,
    String? currencySymbol,
    NotificationSettings? notifications,
    bool? biometricEnabled,
    bool? firstLaunchCompleted,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      colorPalette: colorPalette ?? this.colorPalette,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      notifications: notifications ?? this.notifications,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      firstLaunchCompleted: firstLaunchCompleted ?? this.firstLaunchCompleted,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    colorPalette,
    currencyCode,
    currencySymbol,
    notifications,
    biometricEnabled,
    firstLaunchCompleted,
  ];
}
