import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/onboarding/presentation/widgets/welcome_step_widget.dart';

/// UX-042: a returning user had to invent a throwaway budget before they
/// could restore their backup from Settings.
void main() {
  Widget host({VoidCallback? onRestore, bool isRestoring = false}) =>
      MaterialApp(
        home: Scaffold(
          body: WelcomeStepWidget(
            onContinue: () {},
            onRestore: onRestore,
            isRestoring: isRestoring,
          ),
        ),
      );

  testWidgets('Welcome offers to restore a backup', (tester) async {
    var restores = 0;
    await tester.pumpWidget(host(onRestore: () => restores++));

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Restore from backup'));
    expect(restores, 1);
  });

  testWidgets('both actions rest while a restore runs', (tester) async {
    await tester.pumpWidget(host(onRestore: () {}, isRestoring: true));

    expect(find.text('Restoring…'), findsOneWidget);
    final restore = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Restoring…'),
        matching: find.byType(TextButton),
      ),
    );
    expect(restore.onPressed, isNull);
    final start = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(start.onPressed, isNull);
  });
}
