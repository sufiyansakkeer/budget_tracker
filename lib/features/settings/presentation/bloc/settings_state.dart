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

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.settings = const AppSettings(),
    this.errorMessage,
    this.infoMessage,
    this.isBusy = false,
  });

  SettingsState copyWith({
    SettingsStatus? status,
    AppSettings? settings,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    bool? isBusy,
  }) {
    return SettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      isBusy: isBusy ?? this.isBusy,
    );
  }

  @override
  List<Object?> get props => [
    status,
    settings,
    errorMessage,
    infoMessage,
    isBusy,
  ];
}
