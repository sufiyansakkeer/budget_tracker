import 'package:equatable/equatable.dart';

import '../../domain/entities/notification_settings.dart';
import '../../domain/services/file_delivery_service.dart';

/// Base class for all settings events.
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the persisted settings into the state.
class SettingsLoadEvent extends SettingsEvent {
  const SettingsLoadEvent();
}

/// Updates the application currency.
class SettingsUpdateCurrencyEvent extends SettingsEvent {
  final String code;
  final String symbol;

  const SettingsUpdateCurrencyEvent({required this.code, required this.symbol});

  @override
  List<Object?> get props => [code, symbol];
}

/// Persists and reschedules notification preferences.
class SettingsUpdateNotificationsEvent extends SettingsEvent {
  final NotificationSettings settings;

  const SettingsUpdateNotificationsEvent(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Toggles the biometric lock.
class SettingsUpdateBiometricEvent extends SettingsEvent {
  final bool enabled;

  const SettingsUpdateBiometricEvent(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Exports data (CSV by default, JSON otherwise).
class SettingsExportEvent extends SettingsEvent {
  final bool csv;

  const SettingsExportEvent({this.csv = true});

  @override
  List<Object?> get props => [csv];
}

/// Imports data from a file.
class SettingsImportEvent extends SettingsEvent {
  final String path;
  final bool json;

  const SettingsImportEvent({required this.path, this.json = false});

  @override
  List<Object?> get props => [path, json];
}

/// Creates a backup and saves it to the device or shares it.
class SettingsBackupEvent extends SettingsEvent {
  final FileDestination destination;

  const SettingsBackupEvent(this.destination);

  @override
  List<Object?> get props => [destination];
}

/// Restores from a local backup.
class SettingsRestoreEvent extends SettingsEvent {
  final String path;

  const SettingsRestoreEvent(this.path);

  @override
  List<Object?> get props => [path];
}

/// Resets the current month's budget amount.
class SettingsResetBudgetEvent extends SettingsEvent {
  final double amount;

  const SettingsResetBudgetEvent(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Resets the current month (archives and starts a new month).
class SettingsResetMonthEvent extends SettingsEvent {
  const SettingsResetMonthEvent();
}

/// Clears any transient message shown by the UI.
class SettingsClearMessageEvent extends SettingsEvent {
  const SettingsClearMessageEvent();
}

/// Runs the database integrity check and reports the result.
class SettingsCheckIntegrityEvent extends SettingsEvent {
  const SettingsCheckIntegrityEvent();
}
