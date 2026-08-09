import 'package:budget_tracker/features/settings/presentation/widgets/biometric_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BiometricTile', () {
    testWidgets('renders switch driven by BLoC state (off)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricTile(enabled: false, onChanged: (_) {}),
          ),
        ),
      );

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, false);
    });

    testWidgets('renders switch ON when BLoC state enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BiometricTile(enabled: true, onChanged: (_) {})),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('tapping switch dispatches onChanged with new value', (
      tester,
    ) async {
      bool? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricTile(
              enabled: false,
              onChanged: (v) => changedValue = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(changedValue, true);
    });

    testWidgets('switch disabled while busy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricTile(
              enabled: false,
              isBusy: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      // Shows authenticating subtitle.
      expect(find.text('Authenticating...'), findsOneWidget);
    });

    testWidgets('shows friendly message as subtitle when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricTile(
              enabled: false,
              message:
                  'Biometric authentication isn\'t available on this device.',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Biometric authentication isn\'t available on this device.'),
        findsOneWidget,
      );
    });

    testWidgets('shows default subtitle when no message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricTile(enabled: false, onChanged: (_) {}),
          ),
        ),
      );

      expect(
        find.text('Use fingerprint or Face ID to unlock the app'),
        findsOneWidget,
      );
    });
  });
}
