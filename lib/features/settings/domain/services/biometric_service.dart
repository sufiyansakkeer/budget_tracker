import 'package:local_auth/local_auth.dart';

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
}

/// Wraps [LocalAuth] for biometric lock functionality.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// Returns the biometric capabilities of the device.
  Future<BiometricAvailability> getAvailability() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final types = await _auth.getAvailableBiometrics();
      return BiometricAvailability(
        isDeviceSupported: isSupported,
        canCheckBiometrics: canCheck,
        availableTypes: types,
      );
    } catch (_) {
      return const BiometricAvailability();
    }
  }

  /// Whether the device can use biometrics at all.
  Future<bool> canUseBiometrics() async {
    final availability = await getAvailability();
    return availability.isDeviceSupported && availability.hasBiometrics;
  }

  /// Prompts the user to authenticate with biometrics or device credentials.
  ///
  /// Returns true when authentication succeeds, false when the user cancels
  /// or authentication fails. Never throws on cancellations.
  Future<bool> authenticate({
    String reason = 'Unlock Budget Tracker',
    bool useErrorDialogs = true,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: useErrorDialogs,
        ),
      );
    } catch (e) {
      // Fallback gracefully on unsupported devices.
      return false;
    }
  }
}
