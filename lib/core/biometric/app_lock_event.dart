import 'package:equatable/equatable.dart';

/// Base class for all application lock events.
abstract class AppLockEvent extends Equatable {
  const AppLockEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on app start to determine whether the app must be locked behind
/// the biometric gate. If biometrics are enabled the app becomes locked and
/// immediately prompts; otherwise it becomes unlocked.
class AppStartLockCheck extends AppLockEvent {
  const AppStartLockCheck();
}

/// Requests that the app be locked (e.g. on backgrounding). Does nothing if
/// biometric security is not enabled.
class AppLockRequested extends AppLockEvent {
  const AppLockRequested();
}

/// Requests a new biometric authentication attempt (from a retry button).
class AppUnlockRequested extends AppLockEvent {
  const AppUnlockRequested();
}

/// The user successfully authenticated against the native biometric prompt.
class AppAuthenticated extends AppLockEvent {
  const AppAuthenticated();
}

/// The user cancelled / failed the biometric prompt.
class AppAuthFailed extends AppLockEvent {
  const AppAuthFailed();
}

/// Used by lifecycle handling to mark the app as fully locked (prompt shown).
class AppLocked extends AppLockEvent {
  const AppLocked();
}

/// Settings turned the app lock on or off. Takes effect at once.
class AppLockPreferenceChanged extends AppLockEvent {
  final bool enabled;

  const AppLockPreferenceChanged({required this.enabled});

  @override
  List<Object?> get props => [enabled];
}

/// Re-read the stored app-lock setting (dispatched on resume).
class AppLockSyncRequested extends AppLockEvent {
  const AppLockSyncRequested();
}
