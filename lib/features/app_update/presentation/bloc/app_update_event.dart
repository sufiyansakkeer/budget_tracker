import 'package:equatable/equatable.dart';

abstract class AppUpdateEvent extends Equatable {
  const AppUpdateEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered automatically on app startup to check for updates.
class AppUpdateCheckOnLaunch extends AppUpdateEvent {
  const AppUpdateCheckOnLaunch();
}

/// Triggered manually by the user (e.g. from Settings).
class AppUpdateManualCheck extends AppUpdateEvent {
  const AppUpdateManualCheck();
}

/// The user dismissed the update dialog.
class AppUpdateDismissed extends AppUpdateEvent {
  const AppUpdateDismissed();
}
