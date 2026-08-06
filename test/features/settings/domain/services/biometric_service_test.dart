import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:budget_tracker/features/settings/domain/services/biometric_service.dart';

@GenerateMocks([LocalAuthentication])
import 'biometric_service_test.mocks.dart';

void main() {
  late BiometricService biometricService;
  late MockLocalAuthentication mockAuth;

  setUp(() {
    mockAuth = MockLocalAuthentication();
    biometricService = BiometricService(auth: mockAuth);
  });

  group('BiometricService', () {
    group('getAvailability', () {
      test('should return availability when device supports biometrics', () async {
        when(mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        final availability = await biometricService.getAvailability();

        expect(availability.isDeviceSupported, true);
        expect(availability.canCheckBiometrics, true);
        expect(availability.availableTypes, [BiometricType.fingerprint]);
        expect(availability.hasBiometrics, true);
      });

      test('should return no biometrics when none available', () async {
        when(mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        final availability = await biometricService.getAvailability();

        expect(availability.isDeviceSupported, true);
        expect(availability.canCheckBiometrics, true);
        expect(availability.availableTypes, isEmpty);
        expect(availability.hasBiometrics, false);
      });

      test('should handle errors gracefully', () async {
        when(mockAuth.isDeviceSupported()).thenThrow(Exception('Error'));

        final availability = await biometricService.getAvailability();

        expect(availability.isDeviceSupported, false);
        expect(availability.canCheckBiometrics, false);
        expect(availability.availableTypes, isEmpty);
        expect(availability.hasBiometrics, false);
      });
    });

    group('canUseBiometrics', () {
      test('should return true when device supports and has biometrics', () async {
        when(mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.face]);

        final result = await biometricService.canUseBiometrics();

        expect(result, true);
      });

      test('should return false when device does not support biometrics', () async {
        when(mockAuth.isDeviceSupported()).thenAnswer((_) async => false);

        final result = await biometricService.canUseBiometrics();

        expect(result, false);
      });

      test('should return false when no biometrics available', () async {
        when(mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        final result = await biometricService.canUseBiometrics();

        expect(result, false);
      });
    });

    group('authenticate', () {
      test('should return true on successful authentication', () async {
        when(mockAuth.authenticate(
                localizedReason: anyNamed('localizedReason'),
                options: anyNamed('options')))
            .thenAnswer((_) async => true);

        final result = await biometricService.authenticate(
          reason: 'Test Authentication',
        );

        expect(result, true);
        verify(mockAuth.authenticate(
                localizedReason: 'Test Authentication',
                options: anyNamed('options')))
            .called(1);
      });

      test('should return false on failed authentication', () async {
        when(mockAuth.authenticate(
                localizedReason: anyNamed('localizedReason'),
                options: anyNamed('options')))
            .thenAnswer((_) async => false);

        final result = await biometricService.authenticate();

        expect(result, false);
      });

      test('should return false on cancellation', () async {
        when(mockAuth.authenticate(
                localizedReason: anyNamed('localizedReason'),
                options: anyNamed('options')))
            .thenThrow(Exception('User cancelled'));

        final result = await biometricService.authenticate();

        expect(result, false);
      });

      test('should use default reason when not provided', () async {
        when(mockAuth.authenticate(
                localizedReason: anyNamed('localizedReason'),
                options: anyNamed('options')))
            .thenAnswer((_) async => true);

        await biometricService.authenticate();

        verify(mockAuth.authenticate(
                localizedReason: 'Unlock Budget Tracker',
                options: anyNamed('options')))
            .called(1);
      });

      test('should respect useErrorDialogs parameter', () async {
        when(mockAuth.authenticate(
                localizedReason: anyNamed('localizedReason'),
                options: anyNamed('options')))
            .thenAnswer((_) async => true);

        await biometricService.authenticate(
          reason: 'Test',
          useErrorDialogs: false,
        );

        verify(mockAuth.authenticate(
                localizedReason: 'Test',
                options: argThat(
                  isA<AuthenticationOptions>()
                      .having((o) => o.useErrorDialogs, 'useErrorDialogs', false),
                )))
            .called(1);
      });
    });
  });
}