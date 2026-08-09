import 'package:budget_tracker/core/biometric/app_lock_bloc.dart';
import 'package:budget_tracker/core/biometric/app_lock_event.dart';
import 'package:budget_tracker/core/biometric/app_lock_state.dart';
import 'package:budget_tracker/core/biometric/biometric_initializer.dart';
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
      when(initializer.isAvailable()).thenAnswer((_) async => false);

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
        when(initializer.isAvailable()).thenAnswer((_) async => true);
        when(initializer.authenticateNow()).thenAnswer((_) async => true);

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
      when(initializer.isAvailable()).thenAnswer((_) async => true);
      when(initializer.authenticateNow()).thenAnswer((_) async => false);

      final bloc = buildBloc();
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, AppLockStatus.locked);
      expect(bloc.state.errorMessage, isNotNull);

      await bloc.close();
    });

    test('auth cancelled (false) keeps app locked', () async {
      when(initializer.isAvailable()).thenAnswer((_) async => true);
      when(initializer.authenticateNow()).thenAnswer((_) async => true);

      final bloc = buildBloc();
      // First authenticate to unlock.
      bloc.add(const AppStartLockCheck());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.unlocked);

      // Simulate background -> re-lock, then a cancelled retry.
      bloc.add(const AppLockRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.locked);

      when(initializer.authenticateNow()).thenAnswer((_) async => false);
      bloc.add(const AppUnlockRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, AppLockStatus.locked);

      await bloc.close();
    });

    test('lifecycle re-lock works after unlock', () async {
      when(initializer.isAvailable()).thenAnswer((_) async => true);
      when(initializer.authenticateNow()).thenAnswer((_) async => true);

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
      when(initializer.isAvailable()).thenAnswer((_) async => true);
      var calls = 0;
      when(initializer.authenticateNow()).thenAnswer((_) async {
        calls++;
        // Simulate a slow prompt.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return true;
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

    test('AppAuthenticated event unlocks directly', () async {
      when(initializer.isAvailable()).thenAnswer((_) async => true);
      when(initializer.authenticateNow()).thenAnswer((_) async => false);

      final bloc = buildBloc();
      bloc.add(const AppAuthenticated());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, AppLockStatus.unlocked);

      await bloc.close();
    });
  });
}
