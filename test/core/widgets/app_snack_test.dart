import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/widgets/app_snack.dart';

void main() {
  // UX-110: 33 raw showSnackBar calls with 3, 4 and 6 s durations.
  group('AppSnack', () {
    test('a plain message stays 4 s, one with an action 6 s', () {
      expect(AppSnack.bar('Saved').duration, const Duration(seconds: 4));
      expect(AppSnack.bar('Saved').action, isNull);

      final undo = AppSnack.bar(
        'Expense deleted',
        actionLabel: 'Undo',
        onAction: () {},
        actionKey: const Key('a'),
      );
      expect(undo.duration, const Duration(seconds: 6));
      expect(undo.action?.label, 'Undo');
      expect(undo.action?.key, const Key('a'));
    });

    testWidgets('a new message replaces the one on screen', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      var undone = false;
      AppSnack.show(
        ctx,
        'First',
        actionLabel: 'Undo',
        onAction: () => undone = true,
      );
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);

      AppSnack.show(ctx, 'Second');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(undone, isFalse);

      // The plain one is gone after 4 s.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('the action runs from the snackbar', (tester) async {
      final key = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: key,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      var retried = 0;
      AppSnack.showOn(
        key.currentState!,
        "Couldn't save the bill. Try again.",
        actionLabel: 'Retry',
        onAction: () => retried++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });
  });

  test('every snackbar in lib goes through AppSnack', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_snack.dart')) continue;
      final source = entity.readAsStringSync();
      for (final raw in const [
        'showSnackBar(',
        'SnackBar(',
        'SnackBarAction(',
      ]) {
        // `undoSnackBar(` and `_makeActiveSnackBar(` build theirs with
        // AppSnack.bar; only the raw constructors and calls count.
        final pattern = RegExp(r'(?<![A-Za-z_])' + RegExp.escape(raw));
        if (pattern.hasMatch(source)) offenders.add('${entity.path}: $raw');
      }
    }
    expect(offenders, isEmpty);
  });
}
