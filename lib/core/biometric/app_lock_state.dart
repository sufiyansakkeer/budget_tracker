import 'package:equatable/equatable.dart';

/// Authoritative lock status of the application.
///
/// The UI derives its content from this value:
/// - [AppLockStatus.unlocked] -> render the main application content.
/// - any other value -> render the biometric lock gate.
enum AppLockStatus {
  /// Initial state while the app decides whether biometrics are required.
  checking,

  /// The app is locked behind the biometric gate.
  locked,

  /// A biometric authentication prompt is currently in flight.
  authenticating,

  /// The user has successfully authenticated; the app is visible.
  unlocked,
}

/// The single source of truth for the application lock state.
class AppLockState extends Equatable {
  final AppLockStatus status;

  /// Human-readable error message when the last authentication attempt failed.
  final String? errorMessage;

  const AppLockState({this.status = AppLockStatus.checking, this.errorMessage});

  bool get isLocked => status != AppLockStatus.unlocked;

  bool get isAuthenticating => status == AppLockStatus.authenticating;

  AppLockState copyWith({
    AppLockStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppLockState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
