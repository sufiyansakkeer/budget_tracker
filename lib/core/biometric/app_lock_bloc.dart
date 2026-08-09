import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_lock_event.dart';
import 'app_lock_state.dart';
import 'biometric_initializer.dart';

/// Owns the authoritative application lock state machine.
///
/// State transitions:
/// - On start: runs [AppStartLockCheck]. If biometrics are enabled the app
///   becomes locked and immediately prompts; otherwise it becomes unlocked.
/// - [AppAuthenticated] -> unlocked (the app content is revealed).
/// - [AppAuthFailed] -> locked (stays on the gate).
/// - [AppLockRequested] (e.g. on backgrounding) -> locked again, but only if
///   biometrics are enabled.
///
/// A concurrency guard prevents multiple simultaneous authentication prompts.
class AppLockBloc extends Bloc<AppLockEvent, AppLockState> {
  final BiometricInitializer _biometricInitializer;

  /// Whether an authentication prompt is currently in flight.
  bool _authInProgress = false;

  /// Whether biometric security is enabled (loaded on startup).
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
  }

  Future<void> _onStartLockCheck(
    AppStartLockCheck event,
    Emitter<AppLockState> emit,
  ) async {
    debugPrint('[AppLockBloc] Current state: ${state.status}');
    final available = await _biometricInitializer.isAvailable();
    if (!isClosed) {
      _biometricEnabled = available;
    }

    if (!available) {
      debugPrint('[AppLockBloc] Biometrics not required -> unlocked');
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

      final authenticated = await _biometricInitializer.authenticateNow();
      if (isClosed) return;

      if (authenticated) {
        debugPrint('[AppLockBloc] Authentication successful -> unlocked');
        emit(const AppLockState(status: AppLockStatus.unlocked));
      } else {
        debugPrint('[AppLockBloc] Authentication failed/cancelled -> locked');
        emit(
          const AppLockState(
            status: AppLockStatus.locked,
            errorMessage: 'Authentication failed. Please try again.',
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
        errorMessage: 'Authentication failed. Please try again.',
      ),
    );
  }

  Future<void> _onLocked(AppLocked event, Emitter<AppLockState> emit) async {
    debugPrint('[AppLockBloc] Event: AppLocked');
    emit(const AppLockState(status: AppLockStatus.locked));
  }
}
