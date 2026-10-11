import 'package:flutter/material.dart';
import '../di/injection.dart' as di;
import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/services/biometric_service.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';
import 'lock_auth_result.dart';

/// Reads whether the app lock is on and runs the unlock prompt.
///
/// The lock never opens just because it cannot run. With the lock on, a
/// device with no screen lock and no enrolled biometrics gets
/// [LockAuthResult.unavailable] (the gate explains how to recover), and an
/// unexpected failure gets [LockAuthResult.error]; only a confirmed user
/// gets [LockAuthResult.success].
class BiometricInitializer {
  final BiometricService _biometricService;
  final LoadSettingsUseCase _loadSettingsUseCase;

  BiometricInitializer({
    BiometricService? biometricService,
    LoadSettingsUseCase? loadSettingsUseCase,
  }) : _biometricService = biometricService ?? di.getIt<BiometricService>(),
       _loadSettingsUseCase =
           loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>();

  /// Runs the unlock prompt (biometrics or the device's screen lock).
  Future<LockAuthResult> authenticateNow() async {
    try {
      final availability = await _biometricService.getAvailability();
      if (!availability.canAuthenticate) {
        debugPrint('[Biometric] authenticateNow: nothing to confirm against');
        return LockAuthResult.unavailable;
      }
      final result = await _biometricService.authenticateForUnlock(
        reason: 'Unlock Monivo',
      );
      debugPrint('[Biometric] authenticateNow result: $result');
      return result;
    } catch (e, st) {
      debugPrint('[Biometric] authenticateNow error: $e\n$st');
      return LockAuthResult.error;
    }
  }

  /// Whether the app lock is turned on, or null when the setting cannot be
  /// read (the caller keeps what it already knew).
  ///
  /// This is the stored preference alone. It used to be false whenever the
  /// device had no enrolled biometrics, so removing a fingerprint quietly
  /// switched the lock off while Settings still said "On".
  Future<bool?> isLockEnabled() async {
    try {
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        return data.biometricEnabled;
      }
      return null;
    } catch (e, st) {
      debugPrint('[Biometric] Error reading the app lock setting: $e\n$st');
      return null;
    }
  }
}
