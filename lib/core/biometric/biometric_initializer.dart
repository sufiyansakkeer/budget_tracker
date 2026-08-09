import 'package:flutter/material.dart';
import '../di/injection.dart' as di;
import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/services/biometric_service.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';

/// Handles biometric authentication on app launch.
class BiometricInitializer {
  final BiometricService _biometricService;
  final LoadSettingsUseCase _loadSettingsUseCase;

  BiometricInitializer({
    BiometricService? biometricService,
    LoadSettingsUseCase? loadSettingsUseCase,
  }) : _biometricService = biometricService ?? di.getIt<BiometricService>(),
       _loadSettingsUseCase =
           loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>();

  /// Check if biometric authentication should be performed and authenticate.
  ///
  /// Returns true if authentication succeeded or is not required.
  /// Returns false if authentication failed or was cancelled.
  Future<bool> authenticateIfNeeded() async {
    try {
      // Check if device supports biometrics
      final canUseBiometrics = await _biometricService.canUseBiometrics();
      if (!canUseBiometrics) {
        debugPrint('[Biometric] Device does not support biometrics');
        return true; // Continue without biometric
      }

      // Load settings to check if biometric is enabled
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        final settings = data;
        if (!settings.biometricEnabled) {
          debugPrint('[Biometric] Biometric lock is disabled');
          return true; // Continue without authentication
        }

        // Perform biometric authentication
        final authenticated = await _biometricService.authenticate(
          reason: 'Unlock Budget Tracker',
          useErrorDialogs: true,
        );

        if (authenticated) {
          debugPrint('[Biometric] Biometric authentication successful');
          return true;
        } else {
          debugPrint(
            '[Biometric] Biometric authentication failed or cancelled',
          );
          return false;
        }
      }
    } catch (e, st) {
      debugPrint('[Biometric] Error during biometric authentication: $e\n$st');
      // On error, allow the user to continue (don't lock them out)
      return true;
    }

    return true; // Default to allowing access on error
  }

  /// Performs a native biometric authentication prompt and returns whether it
  /// succeeded. This never shows the lock gate; it is used by the AppLockBloc
  /// after the app has already decided that biometrics are required.
  ///
  /// Returns true on success, false on failure/cancellation. On any unexpected
  /// error the user is allowed to continue (returns true) to avoid locking them
  /// out.
  Future<bool> authenticateNow() async {
    try {
      final canUseBiometrics = await _biometricService.canUseBiometrics();
      if (!canUseBiometrics) {
        debugPrint('[Biometric] authenticateNow: device not supported');
        return true;
      }
      final authenticated = await _biometricService.authenticate(
        reason: 'Unlock Budget Tracker',
        useErrorDialogs: true,
      );
      debugPrint('[Biometric] authenticateNow result: $authenticated');
      return authenticated;
    } catch (e, st) {
      debugPrint('[Biometric] authenticateNow error: $e\n$st');
      return true;
    }
  }

  /// Check if biometric authentication is available on this device.
  Future<bool> isAvailable() async {
    try {
      // Only report "available" if the device supports biometrics AND the
      // biometric lock preference is actually enabled. Otherwise the gate
      // would unnecessarily block the user.
      final canUseBiometrics = await _biometricService.canUseBiometrics();
      if (!canUseBiometrics) {
        return false;
      }
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        return data.biometricEnabled;
      }
      return false;
    } catch (e, st) {
      debugPrint('[Biometric] Error checking biometric availability: $e\n$st');
      return false;
    }
  }
}
