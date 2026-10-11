import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:monivo/core/biometric/biometric_initializer.dart';
import 'package:monivo/core/biometric/lock_auth_result.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/biometric_service.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';

/// UX-012: the lock used to open without asking whenever the device had no
/// enrolled biometrics, and on any error, while Settings still said "On".
void main() {
  test(
    'no screen lock and no biometrics is "unavailable", never success',
    () async {
      final initializer = BiometricInitializer(
        biometricService: _Service(supported: false),
        loadSettingsUseCase: _Settings(enabled: true),
      );
      expect(await initializer.authenticateNow(), LockAuthResult.unavailable);
    },
  );

  test(
    'a screen lock without biometrics still prompts (PIN fallback)',
    () async {
      final service = _Service(supported: true, result: LockAuthResult.success);
      final initializer = BiometricInitializer(
        biometricService: service,
        loadSettingsUseCase: _Settings(enabled: true),
      );
      expect(await initializer.authenticateNow(), LockAuthResult.success);
      expect(service.prompts, 1);
    },
  );

  test('an unexpected failure is an error, never success', () async {
    final initializer = BiometricInitializer(
      biometricService: _Service(supported: true, throwOnPrompt: true),
      loadSettingsUseCase: _Settings(enabled: true),
    );
    expect(await initializer.authenticateNow(), LockAuthResult.error);
  });

  test(
    'the lock is on whenever the setting says so, biometrics or not',
    () async {
      final initializer = BiometricInitializer(
        biometricService: _Service(supported: false),
        loadSettingsUseCase: _Settings(enabled: true),
      );
      expect(await initializer.isLockEnabled(), isTrue);
    },
  );

  test('an unreadable setting is unknown (null), not "off"', () async {
    final initializer = BiometricInitializer(
      biometricService: _Service(supported: true),
      loadSettingsUseCase: _Settings(enabled: true, fail: true),
    );
    expect(await initializer.isLockEnabled(), isNull);
  });

  test('local_auth error codes map to the gate\'s outcomes', () {
    expect(
      BiometricService.lockResultFor(auth_error.passcodeNotSet),
      LockAuthResult.unavailable,
    );
    expect(
      BiometricService.lockResultFor(auth_error.notEnrolled),
      LockAuthResult.unavailable,
    );
    expect(
      BiometricService.lockResultFor(auth_error.notAvailable),
      LockAuthResult.unavailable,
    );
    expect(
      BiometricService.lockResultFor(auth_error.lockedOut),
      LockAuthResult.lockedOut,
    );
    expect(
      BiometricService.lockResultFor(auth_error.permanentlyLockedOut),
      LockAuthResult.lockedOut,
    );
    expect(BiometricService.lockResultFor('Other'), LockAuthResult.error);
  });
}

class _Service extends BiometricService {
  final bool supported;
  final LockAuthResult result;
  final bool throwOnPrompt;
  int prompts = 0;

  _Service({
    required this.supported,
    this.result = LockAuthResult.failed,
    this.throwOnPrompt = false,
  });

  @override
  Future<BiometricAvailability> getAvailability() async =>
      BiometricAvailability(isDeviceSupported: supported);

  @override
  Future<LockAuthResult> authenticateForUnlock({
    String reason = 'Unlock Monivo',
  }) async {
    prompts++;
    if (throwOnPrompt) throw StateError('platform channel failed');
    return result;
  }
}

class _Settings implements LoadSettingsUseCase {
  final bool enabled;
  final bool fail;

  _Settings({required this.enabled, this.fail = false});

  @override
  Future<SettingsResult<AppSettings>> call() async => fail
      ? const SettingsError(
          SettingsFailure(type: SettingsErrorType.loadFailure, message: 'x'),
        )
      : SettingsSuccess(AppSettings(biometricEnabled: enabled));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
