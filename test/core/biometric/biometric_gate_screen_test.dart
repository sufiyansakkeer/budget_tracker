import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monivo/core/biometric/app_lock_bloc.dart';
import 'package:monivo/core/biometric/app_lock_event.dart';
import 'package:monivo/core/biometric/app_lock_state.dart';
import 'package:monivo/core/biometric/lock_auth_result.dart';
import 'package:monivo/core/biometric/biometric_gate_screen.dart';
import 'package:monivo/core/platform/system_ui_session.dart';

import 'app_lock_bloc_test.mocks.dart';

/// The "application" under the gate: its State must survive a lock.
class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  static int mounts = 0;

  @override
  void initState() {
    super.initState();
    mounts++;
  }

  @override
  Widget build(BuildContext context) => const Text('app content');
}

void main() {
  late MockBiometricInitializer initializer;
  late Completer<LockAuthResult> prompt;

  setUp(() {
    _AppState.mounts = 0;
    initializer = MockBiometricInitializer();
    when(initializer.isLockEnabled()).thenAnswer((_) async => true);
    // The prompt never resolves on its own; tests drive the state directly.
    prompt = Completer<LockAuthResult>();
    when(initializer.authenticateNow()).thenAnswer((_) => prompt.future);
  });

  /// Built inside the test body so the bloc's stream subscription lives in
  /// the widget tester's fake-async zone; created in setUp, its handlers
  /// would only resume on the real event loop, after the test finished.
  ({AppLockBloc bloc, Widget widget}) harness() {
    final bloc = AppLockBloc(biometricInitializer: initializer);
    addTearDown(() {
      // close() waits for in-flight handlers; release the pending prompt.
      if (!prompt.isCompleted) prompt.complete(LockAuthResult.failed);
      return bloc.close();
    });
    return (
      bloc: bloc,
      widget: BlocProvider<AppLockBloc>.value(
        value: bloc,
        child: const BiometricGateScreen(child: _App()),
      ),
    );
  }

  testWidgets('shows a blank surface while checking, never the app', (
    tester,
  ) async {
    await tester.pumpWidget(harness().widget);
    expect(find.text('app content'), findsNothing);
    expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
    // The app is already building underneath, ready for the reveal.
    expect(find.text('app content', skipOffstage: false), findsOneWidget);
  });

  testWidgets('keeps the app mounted while locked and reveals it on unlock', (
    tester,
  ) async {
    final (:bloc, :widget) = harness();
    await tester.pumpWidget(widget);
    await tester.pump();
    // Locked (the prompt is in flight): the gate is up and the content is
    // hidden but alive.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    expect(find.text('app content', skipOffstage: false), findsOneWidget);
    expect(find.text('app content'), findsNothing);
    expect(_AppState.mounts, 1);

    // The spinner on the gate animates forever, so settle by hand: the
    // gate fades out over AppMotion.standard.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    bloc.add(const AppAuthenticated());
    await settle();
    expect(find.text('app content'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);

    // Re-locking hides the content again without rebuilding it.
    bloc.add(const AppLocked());
    await settle();
    expect(find.text('app content'), findsNothing);
    expect(find.text('app content', skipOffstage: false), findsOneWidget);

    bloc.add(const AppAuthenticated());
    await settle();
    expect(find.text('app content'), findsOneWidget);
    expect(_AppState.mounts, 1);
  });

  testWidgets(
    'no spinner while the prompt is open; Unlock rests, then returns',
    (tester) async {
      final (:bloc, :widget) = harness();
      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      ButtonStyleButton unlock() => tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Unlock'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Confirm it's you"), findsOneWidget);
      expect(unlock().onPressed, isNull);

      // A dismissed or failed prompt (driven through the bloc, as the
      // prompt's future lives outside the test zone): the button comes back
      // with a plain note.
      bloc.add(const AppAuthFailed());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Unlock to continue'), findsOneWidget);
      expect(
        find.textContaining('Not unlocked. Tap Unlock to try again.'),
        findsOneWidget,
      );
      expect(unlock().onPressed, isNotNull);
      expect(bloc.state.status, AppLockStatus.locked);

      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );

  testWidgets('a lockout is explained under the description, icon inline and '
      'announced (UX-069)', (tester) async {
    // Made in the test body so its completion runs in the test's zone.
    prompt = Completer<LockAuthResult>();
    final (:bloc, :widget) = harness();
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The pending prompt reports a lockout.
    prompt.complete(LockAuthResult.lockedOut);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final note = find.textContaining('Too many attempts');
    expect(note, findsOneWidget);
    expect(find.text('Unlock to continue'), findsOneWidget);
    // The icon sits inside the centred text, not at the row's far edge.
    expect(
      find.descendant(
        of: note,
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: note,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    expect(bloc.state.status, AppLockStatus.locked);
  });

  group('system screens the app opens itself', () {
    tearDown(() {
      SystemUiSession.reset();
      SystemUiSession.clock = DateTime.now;
    });

    Future<AppLockBloc> unlocked(WidgetTester tester) async {
      final (:bloc, :widget) = harness();
      await tester.pumpWidget(widget);
      await tester.pump();
      bloc.add(const AppAuthenticated());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(bloc.state.status, AppLockStatus.unlocked);
      return bloc;
    }

    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    testWidgets('a picker or share sheet does not lock the app', (
      tester,
    ) async {
      final bloc = await unlocked(tester);
      final picker = Completer<void>();
      final session = SystemUiSession.run(() => picker.future);

      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);

      lifecycle(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      picker.complete();
      await session;
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);

      // Leaving the app afterwards, for longer than the grace period,
      // locks as usual.
      var now = DateTime(2026, 10, 10, 12);
      SystemUiSession.clock = () => now;
      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      now = now.add(BiometricGateScreen.lockGracePeriod);
      lifecycle(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      expect(bloc.state.status, isNot(AppLockStatus.unlocked));
    });

    testWidgets('a system screen left open past the limit locks on return', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 10, 12);
      SystemUiSession.clock = () => now;
      final bloc = await unlocked(tester);
      final picker = Completer<void>();
      final session = SystemUiSession.run(() => picker.future);

      lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);

      now = now.add(SystemUiSession.maxDuration + const Duration(seconds: 1));
      lifecycle(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      picker.complete();
      await session;
      await tester.pump();
      expect(bloc.state.status, isNot(AppLockStatus.unlocked));
    });
  });

  group('leaving and coming back', () {
    late DateTime now;
    late List<Completer<LockAuthResult>> prompts;

    setUp(() {
      now = DateTime(2026, 10, 10, 12);
      SystemUiSession.clock = () => now;
      // Each prompt is made when it is shown, inside the test zone, so
      // completing it resumes the bloc under the fake clock. Every test
      // closes its prompts before it ends.
      prompts = [];
      when(initializer.authenticateNow()).thenAnswer((_) {
        final prompt = Completer<LockAuthResult>();
        prompts.add(prompt);
        return prompt.future;
      });
    });

    tearDown(() {
      SystemUiSession.reset();
      SystemUiSession.clock = DateTime.now;
    });

    Future<AppLockBloc> start(WidgetTester tester) async {
      final (:bloc, :widget) = harness();
      await tester.pumpWidget(widget);
      await tester.pump();
      expect(prompts, hasLength(1));
      return bloc;
    }

    Future<AppLockBloc> unlocked(WidgetTester tester) async {
      final bloc = await start(tester);
      prompts.single.complete(LockAuthResult.success);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(bloc.state.status, AppLockStatus.unlocked);
      return bloc;
    }

    void leave(WidgetTester tester) {
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    Future<void> comeBack(WidgetTester tester) async {
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a system prompt or Control Center (inactive) never locks', (
      tester,
    ) async {
      final bloc = await unlocked(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      now = now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);
      expect(prompts, hasLength(1));
    });

    testWidgets('a short trip to another app does not lock', (tester) async {
      final bloc = await unlocked(tester);
      leave(tester);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);
      // Covered while away, so the app-switcher snapshot shows no figures.
      expect(find.text('app content'), findsNothing);
      expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);

      now = now.add(
        BiometricGateScreen.lockGracePeriod - const Duration(seconds: 1),
      );
      await comeBack(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(bloc.state.status, AppLockStatus.unlocked);
      expect(prompts, hasLength(1));
      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('past the grace period it locks and prompts at once', (
      tester,
    ) async {
      final bloc = await unlocked(tester);
      leave(tester);
      now = now.add(BiometricGateScreen.lockGracePeriod);
      await comeBack(tester);
      expect(bloc.state.status, AppLockStatus.authenticating);
      expect(prompts, hasLength(2));

      prompts.last.complete(LockAuthResult.success);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);
    });

    testWidgets('coming back to the lock screen prompts again', (tester) async {
      final bloc = await start(tester);
      prompts.single.complete(LockAuthResult.failed);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.locked);

      leave(tester);
      now = now.add(const Duration(seconds: 5));
      await comeBack(tester);
      expect(bloc.state.status, AppLockStatus.authenticating);
      expect(prompts, hasLength(2));

      // Closed inside the test: bloc.close() waits for an open prompt, and
      // a prompt made in the test zone only resumes while the test pumps.
      prompts.last.complete(LockAuthResult.failed);
      await tester.pump();
    });

    testWidgets("the prompt's own screen (the PIN pad) is not leaving", (
      tester,
    ) async {
      final bloc = await start(tester);
      expect(bloc.state.status, AppLockStatus.authenticating);
      // Android shows the device PIN as its own screen.
      leave(tester);
      now = now.add(const Duration(minutes: 1));
      await comeBack(tester);
      expect(prompts, hasLength(1));

      prompts.single.complete(LockAuthResult.success);
      await tester.pump();
      expect(bloc.state.status, AppLockStatus.unlocked);
    });
  });
}
