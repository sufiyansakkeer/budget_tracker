import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_lock_event.dart';
import 'app_lock_state.dart';
import 'biometric_initializer.dart';
import 'lock_auth_result.dart';

/// Owns the authoritative application lock state machine.
///
/// State transitions:
/// - On start: runs [AppStartLockCheck]. If biometrics are enabled the app
///   becomes locked and immediately prompts; otherwise it becomes unlocked.
/// - [AppAuthenticated] -> unlocked (the app content is revealed).
/// - [AppAuthFailed] -> locked (stays on the gate).
/// - [AppLockRequested] (e.g. on backgrounding) -> locked again, but only if
///   the lock is on.
/// - [AppLockPreferenceChanged] (Settings turned the lock on or off) takes
///   effect at once; it used to need a restart. [AppLockSyncRequested] (on
///   resume) re-reads the stored setting, e.g. after a restore.
///
/// Only a confirmed user unlocks. When the check cannot run (no screen lock,
/// locked out, an error) the gate stays up and says how to recover.
///
/// A concurrency guard prevents multiple simultaneous authentication prompts.
class AppLockBloc extends Bloc<AppLockEvent, AppLockState> {
  /// Shown after a failed or dismissed prompt; dismissing is not an error,
  /// so the copy only says what happened and what to do.
  static const _notUnlocked = 'Not unlocked. Tap Unlock to try again.';

  /// The device has nothing to confirm the user against.
  static const noScreenLock =
      "This phone has no screen lock or fingerprint set up, so Monivo can't "
      "confirm it's you. Set up a screen lock in your phone's settings, then "
      'tap Unlock.';

  /// The system paused authentication after too many attempts.
  static const lockedOutMessage =
      'Too many attempts. Unlock your phone with its PIN or password, then '
      'tap Unlock.';

  /// An unexpected failure; trying again may work.
  static const checkFailed =
      "Couldn't confirm it's you. Tap Unlock to try again.";

  final BiometricInitializer _biometricInitializer;

  /// Whether an authentication prompt is currently in flight.
  bool _authInProgress = false;

  /// Whether the app lock is on: read at start, then kept current by
  /// [AppLockPreferenceChanged] and [AppLockSyncRequested].
  bool _biometricEnabled = false;

  AppLockBloc({required BiometricInitializer biometricInitializer})
    : _biometricInitializer = biometricInitializer,
      super(const AppLockState()) {
    on<AppStartLockCheck>(_onStartLockCheck);
    on<AppLockRequested>(_onLockRequested);
    on<AppUnlockRequested>(_onUnlockRequested);
    on<AppAuthenticated>(_onAuthenticated);
    on<AppAuthFailed>(_onAuthFailed);
    on<AppLocked>(_onLocked);
    on<AppLockPreferenceChanged>(_onPreferenceChanged);
    on<AppLockSyncRequested>(_onSyncRequested);
  }

  Future<void> _onStartLockCheck(
    AppStartLockCheck event,
    Emitter<AppLockState> emit,
  ) async {
    debugPrint('[AppLockBloc] Current state: ${state.status}');
    // The setting alone decides: a lock that is on is never skipped because
    // the device cannot run it (the prompt then explains how to recover).
    final enabled = await _biometricInitializer.isLockEnabled() ?? false;
    if (!isClosed) {
      _biometricEnabled = enabled;
    }

    if (!enabled) {
      debugPrint('[AppLockBloc] App lock off -> unlocked');
      emit(const AppLockState(status: AppLockStatus.unlocked));
      return;
    }

    debugPrint('[AppLockBloc] Biometrics required -> locked');
    emit(const AppLockState(status: AppLockStatus.locked));
    // Kick off the first authentication prompt.
    add(const AppUnlockRequested());
  }

  Future<void> _onLockRequested(
    AppLockRequested event,
    Emitter<AppLockState> emit,
  ) async {
    if (!_biometricEnabled) {
      debugPrint(
        '[AppLockBloc] Lock requested but biometrics disabled -> staying unlocked',
      );
      if (state.status != AppLockStatus.unlocked) {
        emit(const AppLockState(status: AppLockStatus.unlocked));
      }
      return;
    }

    // Only relock if we are currently unlocked. If we are already locked or
    // authenticating, do nothing (avoid re-prompting).
    if (state.status == AppLockStatus.unlocked) {
      debugPrint('[AppLockBloc] Backgrounding -> locked');
      emit(const AppLockState(status: AppLockStatus.locked));
    }
  }

  Future<void> _onUnlockRequested(
    AppUnlockRequested event,
    Emitter<AppLockState> emit,
  ) async {
    // Guard against concurrent authentication attempts (STEP 14).
    if (_authInProgress) {
      debugPrint(
        '[AppLockBloc] Authentication already in progress; ignoring request',
      );
      return;
    }
    _authInProgress = true;

    try {
      emit(
        state.copyWith(status: AppLockStatus.authenticating, clearError: true),
      );
      debugPrint('[AppLockBloc] Event: AppUnlockRequested (authenticating)');

      final result = await _biometricInitializer.authenticateNow();
      if (isClosed) return;

      if (result == LockAuthResult.success) {
        debugPrint('[AppLockBloc] Authentication successful -> unlocked');
        emit(const AppLockState(status: AppLockStatus.unlocked));
      } else {
        debugPrint('[AppLockBloc] Not unlocked ($result) -> locked');
        emit(
          AppLockState(
            status: AppLockStatus.locked,
            errorMessage: switch (result) {
              LockAuthResult.unavailable => noScreenLock,
              LockAuthResult.lockedOut => lockedOutMessage,
              LockAuthResult.error => checkFailed,
              LockAuthResult.failed || LockAuthResult.success => _notUnlocked,
            },
          ),
        );
      }
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> _onAuthenticated(
    AppAuthenticated event,
    Emitter<AppLockState> emit,
  ) async {
    debugPrint('[AppLockBloc] Event: AppAuthenticated -> unlocked');
    emit(const AppLockState(status: AppLockStatus.unlocked));
  }

  Future<void> _onAuthFailed(
    AppAuthFailed event,
    Emitter<AppLockState> emit,
  ) async {
    debugPrint('[AppLockBloc] Event: AppAuthFailed -> locked');
    emit(
      const AppLockState(
        status: AppLockStatus.locked,
        errorMessage: _notUnlocked,
      ),
    );
  }

  Future<void> _onLocked(AppLocked event, Emitter<AppLockState> emit) async {
    debugPrint('[AppLockBloc] Event: AppLocked');
    emit(const AppLockState(status: AppLockStatus.locked));
  }

  /// Settings saved a new value: the next background locks (or not) at
  /// once, without a restart.
  void _onPreferenceChanged(
    AppLockPreferenceChanged event,
    Emitter<AppLockState> emit,
  ) {
    debugPrint('[AppLockBloc] Lock turned ${event.enabled ? 'on' : 'off'}');
    _biometricEnabled = event.enabled;
    if (!event.enabled && state.status != AppLockStatus.unlocked) {
      emit(const AppLockState(status: AppLockStatus.unlocked));
    }
  }

  /// Re-reads the stored setting (on resume), so a change made any other
  /// way, such as a restore, is honoured. An unreadable setting keeps the
  /// value already known.
  Future<void> _onSyncRequested(
    AppLockSyncRequested event,
    Emitter<AppLockState> emit,
  ) async {
    final enabled = await _biometricInitializer.isLockEnabled();
    if (enabled != null && !isClosed) _biometricEnabled = enabled;
  }
}
