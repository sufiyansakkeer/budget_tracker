import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_ring.dart';

void main() {
  group('TargetRingLaps', () {
    test('spent below the target fills part of one lap', () {
      const laps = TargetRingLaps(spent: 570, target: 867.62);
      expect(laps.spent, closeTo(0.657, 0.001));
      expect(laps.over, 0);
    });

    test('spent exactly the target closes the lap, nothing over', () {
      const laps = TargetRingLaps(spent: 1000, target: 1000);
      expect((laps.spent, laps.over), (1.0, 0.0));
    });

    test('over the target: a full lap, and the excess as an inner lap', () {
      const laps = TargetRingLaps(spent: 1400, target: 1000);
      expect(laps.spent, 1);
      expect(laps.over, closeTo(0.4, 1e-9));
    });

    test('the inner lap stops at one full turn', () {
      const laps = TargetRingLaps(spent: 5000, target: 1000);
      expect(laps.over, 1);
    });

    test('one arc per expense, in order, inside the lap (blueprint)', () {
      const laps = TargetRingLaps(spent: 570, target: 867.62);
      final arcs = laps.arcs(const [180, 390]);
      expect(arcs, hasLength(2));
      expect(arcs[0].$1, 0);
      expect(arcs[0].$2, closeTo(180 / 867.62, 1e-9));
      expect(arcs[1].$1, closeTo(180 / 867.62, 1e-9));
      expect(arcs[1].$2, closeTo(390 / 867.62, 1e-9));
    });

    test('arcs stop at the full lap; the rest is the inner lap', () {
      const laps = TargetRingLaps(spent: 1100, target: 1000);
      final arcs = laps.arcs(const [500, 600]);
      expect(arcs[1].$1, 0.5);
      expect(arcs[1].$2, 0.5);
      expect(laps.over, closeTo(0.1, 1e-9));
    });

    test('with no target, any spending is all over', () {
      expect(const TargetRingLaps(spent: 0, target: 0).spent, 0);
      const laps = TargetRingLaps(spent: 10, target: 0);
      expect((laps.spent, laps.over), (1.0, 1.0));
    });
  });

  testWidgets('one labelled image with the centre inside', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: TargetRing(
              spent: 570,
              target: 867.62,
              semanticsLabel: 'Left today ₹297',
              child: Text('centre'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('centre'), findsOneWidget);
    expect(find.bySemanticsLabel('Left today ₹297'), findsOneWidget);
    expect(tester.getSize(find.byType(TargetRing)).width, TargetRing.size);
    handle.dispose();
  });
}
