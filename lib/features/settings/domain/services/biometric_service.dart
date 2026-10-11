import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

import '../../../../core/biometric/lock_auth_result.dart';

/// Result of a biometric capability / authentication check.
class BiometricAvailability {
  final bool isDeviceSupported;
  final bool canCheckBiometrics;
  final List<BiometricType> availableTypes;

  const BiometricAvailability({
    this.isDeviceSupported = false,
    this.canCheckBiometrics = false,
    this.availableTypes = const [],
  });

  bool get hasBiometrics => availableTypes.isNotEmpty;

  /// Whether the device can confirm the user at all: a screen lock (PIN,
  /// pattern, password, passcode) or enrolled biometrics. Unlocking accepts
  /// either, so the app lock needs only this.
  bool get canAuthenticate => isDeviceSupported;
}

/// Wraps [LocalAuth] for biometric lock functionality.
///
/// All methods log each step of the native authentication flow so that a
/// failure can be diagnosed from the console instead of being silently
/// swallowed. This is critical because the plugin throws a
/// [PlatformException] for many error conditions (e.g. hardware unavailable,
/// no enrolled biometrics, or a transient platform error).
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// Returns the biometric capabilities of the device.
  ///
  /// Unlike the previous implementation, this does NOT swallow a transient
  /// exception and collapse it into "not supported". Each capability is
  /// queried independently and best-effort, while still logging the real
  /// error so the cause is visible.
  Future<BiometricAvailability> getAvailability() async {
    debugPrint('[Biometric] Service initialized');

    bool isSupported = false;
    bool canCheck = false;
    List<BiometricType> types = const [];

    try {
      isSupported = await _auth.isDeviceSupported();
      debugPrint('[Biometric] Device supported: $isSupported');
    } catch (e, st) {
      debugPrint('[Biometric] isDeviceSupported threw: $e\n$st');
    }

    try {
      canCheck = await _auth.canCheckBiometrics;
      debugPrint('[Biometric] canCheckBiometrics: $canCheck');
    } catch (e, st) {
      debugPrint('[Biometric] canCheckBiometrics threw: $e\n$st');
    }

    try {
      types = await _auth.getAvailableBiometrics();
      debugPrint('[Biometric] Available biometrics: $types');
    } catch (e, st) {
      debugPrint('[Biometric] getAvailableBiometrics threw: $e\n$st');
    }

    return BiometricAvailability(
      isDeviceSupported: isSupported,
      canCheckBiometrics: canCheck,
      availableTypes: types,
    );
  }

  /// Whether the device can use biometrics at all.
  Future<bool> canUseBiometrics() async {
    final availability = await getAvailability();
    return availability.isDeviceSupported && availability.hasBiometrics;
  }

  /// Prompts the user to unlock the app with biometrics or the device's
  /// screen lock, and says how it went. Never reports [LockAuthResult.success]
  /// unless the platform confirmed the user.
  Future<LockAuthResult> authenticateForUnlock({
    String reason = 'Unlock Monivo',
  }) async {
    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return result ? LockAuthResult.success : LockAuthResult.failed;
    } on PlatformException catch (e, st) {
      debugPrint('[Biometric] Unlock exception ${e.code}: $e\n$st');
      return lockResultFor(e.code);
    } catch (e, st) {
      debugPrint('[Biometric] Unlock exception: $e\n$st');
      return LockAuthResult.error;
    }
  }

  /// The [LockAuthResult] for a `local_auth` error code.
  @visibleForTesting
  static LockAuthResult lockResultFor(String code) => switch (code) {
    auth_error.notAvailable ||
    auth_error.passcodeNotSet ||
    auth_error.notEnrolled => LockAuthResult.unavailable,
    auth_error.lockedOut ||
    auth_error.permanentlyLockedOut => LockAuthResult.lockedOut,
    _ => LockAuthResult.error,
  };

  /// Prompts the user to authenticate with biometrics or device credentials.
  ///
  /// Returns true when authentication succeeds, false when the user cancels
  /// or authentication fails. Exceptions are logged (not swallowed) so the
  /// underlying error code is always visible in the console.
  Future<bool> authenticate({
    String reason = 'Unlock Monivo',
    bool useErrorDialogs = true,
  }) async {
    debugPrint('[Biometric] Calling authenticate() reason="$reason"');
    try {
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: useErrorDialogs,
        ),
      );
      debugPrint('[Biometric] Authentication result: $result');
      return result;
    } catch (e, st) {
      // Do NOT swallow silently. Log the exception and error code so the
      // actual failure can be diagnosed.
      debugPrint('[Biometric] Authentication exception: $e\n$st');
      return false;
    }
  }
}
