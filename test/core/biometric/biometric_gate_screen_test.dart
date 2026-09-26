import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monivo/core/biometric/app_lock_bloc.dart';
import 'package:monivo/core/biometric/app_lock_event.dart';
import 'package:monivo/core/biometric/biometric_gate_screen.dart';

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
  late Completer<bool> prompt;

  setUp(() {
    _AppState.mounts = 0;
    initializer = MockBiometricInitializer();
    when(initializer.isAvailable()).thenAnswer((_) async => true);
    // The prompt never resolves on its own; tests drive the state directly.
    prompt = Completer<bool>();
    when(initializer.authenticateNow()).thenAnswer((_) => prompt.future);
  });

  /// Built inside the test body so the bloc's stream subscription lives in
  /// the widget tester's fake-async zone; created in setUp, its handlers
  /// would only resume on the real event loop, after the test finished.
  ({AppLockBloc bloc, Widget widget}) harness() {
    final bloc = AppLockBloc(biometricInitializer: initializer);
    addTearDown(() {
      // close() waits for in-flight handlers; release the pending prompt.
      if (!prompt.isCompleted) prompt.complete(false);
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
}
