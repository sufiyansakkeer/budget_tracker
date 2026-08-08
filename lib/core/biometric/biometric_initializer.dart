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
  })  : _biometricService = biometricService ?? di.getIt<BiometricService>(),
        _loadSettingsUseCase = loadSettingsUseCase ?? di.getIt<LoadSettingsUseCase>();

  /// Check if biometric authentication should be performed and authenticate.
  ///
  /// Returns true if authentication succeeded or is not required.
  /// Returns false if authentication failed or was cancelled.
  Future<bool> authenticateIfNeeded() async {
    try {
      // Check if device supports biometrics
      final canUseBiometrics = await _biometricService.canUseBiometrics();
      if (!canUseBiometrics) {
        debugPrint('Device does not support biometrics');
        return true; // Continue without biometric
      }

      // Load settings to check if biometric is enabled
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        final settings = data;
        if (!settings.biometricEnabled) {
          debugPrint('Biometric lock is disabled');
          return true; // Continue without authentication
        }

        // Perform biometric authentication
        final authenticated = await _biometricService.authenticate(
          reason: 'Unlock Budget Tracker',
          useErrorDialogs: true,
        );

        if (authenticated) {
          debugPrint('Biometric authentication successful');
          return true;
        } else {
          debugPrint('Biometric authentication failed or cancelled');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      // On error, allow the user to continue (don't lock them out)
      return true;
    }

    return true; // Default to allowing access on error
  }

  /// Check if biometric authentication is available on this device.
  Future<bool> isAvailable() async {
    try {
      return await _biometricService.canUseBiometrics();
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }
}