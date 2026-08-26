import 'package:equatable/equatable.dart';

import '../../domain/entities/app_update_result.dart';

abstract class AppUpdateState extends Equatable {
  const AppUpdateState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any check has been performed.
class AppUpdateInitial extends AppUpdateState {
  const AppUpdateInitial();
}

/// A check is in progress.
class AppUpdateChecking extends AppUpdateState {
  const AppUpdateChecking();
}

/// An update is available. Contains all information for the UI.
class AppUpdateAvailable extends AppUpdateState {
  final AppUpdateResult result;

  const AppUpdateAvailable(this.result);

  @override
  List<Object?> get props => [result];
}

/// The app is up to date (or running a newer version).
class AppUpdateUpToDate extends AppUpdateState {
  final AppUpdateResult result;

  const AppUpdateUpToDate(this.result);

  @override
  List<Object?> get props => [result];
}

/// The update check failed.
class AppUpdateCheckFailed extends AppUpdateState {
  final String message;

  const AppUpdateCheckFailed(this.message);

  @override
  List<Object?> get props => [message];
}
