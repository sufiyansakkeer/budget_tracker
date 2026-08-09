import 'package:equatable/equatable.dart';

import '../../domain/entities/app_settings.dart';

enum SettingsStatus { initial, loading, loaded, error }

/// Holds the current settings and status.
class SettingsState extends Equatable {
  final SettingsStatus status;
  final AppSettings settings;
  final String? errorMessage;
  final String? infoMessage;
  final bool isBusy;

  /// True while a biometric authentication / availability check is running.
  final bool isBiometricBusy;

  /// Friendly, persistent message about biometric availability/state.
  /// Shown as the Biometric Lock subtitle (e.g. "Not available on this device"
  /// or "Please set up fingerprint or Face ID on your device first.").
  final String? biometricMessage;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.settings = const AppSettings(),
    this.errorMessage,
    this.infoMessage,
    this.isBusy = false,
    this.isBiometricBusy = false,
    this.biometricMessage,
  });

  SettingsState copyWith({
    SettingsStatus? status,
    AppSettings? settings,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    bool? isBusy,
    bool? isBiometricBusy,
    String? biometricMessage,
    bool clearBiometricMessage = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      isBusy: isBusy ?? this.isBusy,
      isBiometricBusy: isBiometricBusy ?? this.isBiometricBusy,
      biometricMessage: clearBiometricMessage
          ? null
          : (biometricMessage ?? this.biometricMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    settings,
    errorMessage,
    infoMessage,
    isBusy,
    isBiometricBusy,
    biometricMessage,
  ];
}
