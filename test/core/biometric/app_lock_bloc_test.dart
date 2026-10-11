import 'package:monivo/core/biometric/app_lock_bloc.dart';
import 'package:monivo/core/biometric/app_lock_event.dart';
import 'package:monivo/core/biometric/app_lock_state.dart';
import 'package:monivo/core/biometric/biometric_initializer.dart';
import 'package:monivo/core/biometric/lock_auth_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([BiometricInitializer])
import 'app_lock_bloc_test.mocks.dart';

void main() {
  group('AppLockBloc', () {
    late MockBiometricInitializer initializer;

    AppLockBloc buildBloc() {
      return AppLockBloc(biometricInitializer: initializer);
    }

    setUp(() {
      initializer = MockBiometricInitializer();
    });

    test('start: biometrics not required -> unlocked immediately', () async {
      when(initializer.isLockEnabled()).thenAnswer((_) async => false);

      final bloc = buildBloc();
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, AppLockStatus.unlocked);
      verifyNever(initializer.authenticateNow());

      await bloc.close();
    });

    test(
      'start + auth success: locked -> authenticating -> unlocked',
      () async {
        when(initializer.isLockEnabled()).thenAnswer((_) async => true);
        when(
          initializer.authenticateNow(),
        ).thenAnswer((_) async => LockAuthResult.success);

        final bloc = buildBloc();
        final states = <AppLockStatus>[];
        bloc.stream.listen((s) => states.add(s.status));

        bloc.add(const AppStartLockCheck());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, AppLockStatus.unlocked);
        expect(states, contains(AppLockStatus.locked));
        expect(states, contains(AppLockStatus.authenticating));
        expect(states, contains(AppLockStatus.unlocked));

        await bloc.close();
      },
    );

    test('auth failure: locked -> authenticating -> locked', () async {
      when(initializer.isLockEnabled()).thenAnswer((_) async => true);
      when(
        initializer.authenticateNow(),
      ).thenAnswer((_) async => LockAuthResult.failed);

      final bloc = buildBloc();
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, AppLockStatus.locked);
      expect(bloc.state.errorMessage, isNotNull);

      await bloc.close();
    });

    test('auth cancelled (false) keeps app locked', () async {
      when(initializer.isLockEnabled()).thenAnswer((_) async => true);
      when(
        initializer.authenticateNow(),
      ).thenAnswer((_) async => LockAuthResult.success);

      final bloc = buildBloc();
      // First authenticate to unlock.
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.unlocked);

      // Simulate background -> re-lock, then a cancelled retry.
      bloc.add(const AppLockRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.locked);

      when(
        initializer.authenticateNow(),
      ).thenAnswer((_) async => LockAuthResult.failed);
      bloc.add(const AppUnlockRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.locked);

      await bloc.close();
    });

    test('lifecycle re-lock works after unlock', () async {
      when(initializer.isLockEnabled()).thenAnswer((_) async => true);
      when(
        initializer.authenticateNow(),
      ).thenAnswer((_) async => LockAuthResult.success);

      final bloc = buildBloc();
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.unlocked);

      bloc.add(const AppLockRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.locked);

      await bloc.close();
    });

    test('concurrent auth requests are guarded to a single prompt', () async {
      when(initializer.isLockEnabled()).thenAnswer((_) async => true);
      var calls = 0;
      when(initializer.authenticateNow()).thenAnswer((_) async {
        calls++;
        // Simulate a slow prompt.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return LockAuthResult.success;
      });

      final bloc = buildBloc();
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);

      // Fire two unlock requests while the first may still be in flight.
      bloc.add(const AppUnlockRequested());
      bloc.add(const AppUnlockRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, AppLockStatus.unlocked);
      // At most 2 calls: the initial one from start + one more (the second
      // concurrent request should have been ignored).
      expect(calls, lessThanOrEqualTo(2));

      await bloc.close();
    });

    group('UX-011: the setting takes effect without a restart', () {
      test('turning the lock on locks the next time the app leaves', () async {
        when(initializer.isLockEnabled()).thenAnswer((_) async => false);
        final bloc = buildBloc();
        bloc.add(const AppStartLockCheck());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, AppLockStatus.unlocked);

        bloc.add(const AppLockPreferenceChanged(enabled: true));
        bloc.add(const AppLockRequested());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, AppLockStatus.locked);
        await bloc.close();
      });

      test('turning the lock off stops the re-lock at once', () async {
        when(initializer.isLockEnabled()).thenAnswer((_) async => true);
        when(
          initializer.authenticateNow(),
        ).thenAnswer((_) async => LockAuthResult.success);
        final bloc = buildBloc();
        bloc.add(const AppStartLockCheck());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, AppLockStatus.unlocked);

        bloc.add(const AppLockPreferenceChanged(enabled: false));
        bloc.add(const AppLockRequested());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, AppLockStatus.unlocked);
        await bloc.close();
      });

      test(
        'a resume re-reads the stored setting (e.g. after a restore)',
        () async {
          when(initializer.isLockEnabled()).thenAnswer((_) async => false);
          final bloc = buildBloc();
          bloc.add(const AppStartLockCheck());
          await Future<void>.delayed(Duration.zero);

          when(initializer.isLockEnabled()).thenAnswer((_) async => true);
          bloc.add(const AppLockSyncRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const AppLockRequested());
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.status, AppLockStatus.locked);
          await bloc.close();
        },
      );

      test('an unreadable setting keeps the value already known', () async {
        when(initializer.isLockEnabled()).thenAnswer((_) async => true);
        when(
          initializer.authenticateNow(),
        ).thenAnswer((_) async => LockAuthResult.success);
        final bloc = buildBloc();
        bloc.add(const AppStartLockCheck());
        await Future<void>.delayed(Duration.zero);

        when(initializer.isLockEnabled()).thenAnswer((_) async => null);
        bloc.add(const AppLockSyncRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AppLockRequested());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.status, AppLockStatus.locked);
        await bloc.close();
      });
    });

    group('UX-012: only a confirmed user unlocks', () {
      for (final (result, message) in [
        (LockAuthResult.unavailable, AppLockBloc.noScreenLock),
        (LockAuthResult.lockedOut, AppLockBloc.lockedOutMessage),
        (LockAuthResult.error, AppLockBloc.checkFailed),
      ]) {
        test('$result keeps the gate up and says what to do', () async {
          when(initializer.isLockEnabled()).thenAnswer((_) async => true);
          when(initializer.authenticateNow()).thenAnswer((_) async => result);

          final bloc = buildBloc();
          bloc.add(const AppStartLockCheck());
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.status, AppLockStatus.locked);
          expect(bloc.state.errorMessage, message);
          await bloc.close();
        });
      }
    });

    test('AppAuthenticated event unlocks directly', () async {
      when(initializer.isLockEnabled()).thenAnswer((_) async => true);
      when(
        initializer.authenticateNow(),
      ).thenAnswer((_) async => LockAuthResult.failed);

      final bloc = buildBloc();
      bloc.add(const AppAuthenticated());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, AppLockStatus.unlocked);

      await bloc.close();
    });
  });
}
