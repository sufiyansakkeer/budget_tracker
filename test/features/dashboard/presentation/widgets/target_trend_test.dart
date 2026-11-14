import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/day_target.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_trend.dart';

void main() {
  DayTarget day(int d, double target, double spent) => DayTarget(
    date: DateTime(2026, 10, d),
    target: target,
    spent: spent,
    result: target - spent,
  );

  testWidgets('says where the target started and where it is (blueprint)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TargetTrend(
            currency: 'INR',
            days: [
              day(1, 1779.03, 3900),
              day(2, 1708.33, 6200),
              day(8, 867.62, 570),
            ],
          ),
        ),
      ),
    );

    expect(find.text('How it has moved'), findsOneWidget);
    expect(find.text('₹1,779 on 1 Oct, ₹868 today'), findsOneWidget);
    expect(find.byKey(const Key('targetTrendChart')), findsOneWidget);
  });

  testWidgets('nothing to show with a single day', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TargetTrend(currency: 'INR', days: [day(1, 1000, 0)]),
        ),
      ),
    );
    expect(find.text('How it has moved'), findsNothing);
  });
}
