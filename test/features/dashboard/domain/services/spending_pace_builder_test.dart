import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/services/spending_pace_builder.dart';

void main() {
  final calculator = SafeToSpendCalculator(BudgetCalculationService());

  // 1–30 Oct, ₹3,000. Today is 5 Oct (day 5 of 30).
  SafeToSpendInput input({
    DateTime? today,
    double periodSpent = 0,
    double todaySpent = 0,
    double committedInPeriod = 0,
    double? savings,
  }) => SafeToSpendInput(
    budgetId: 'b1',
    budgetName: 'October',
    currency: 'INR',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 30),
    today: today ?? DateTime(2026, 10, 5),
    budgetAmount: 3000,
    periodSpent: periodSpent,
    todaySpent: todaySpent,
    committedSpentInPeriod: committedInPeriod,
    committedSpentToday: 0,
    commitments: const [],
    savingsTarget: savings,
  );

  test('accumulates spending day by day through today', () {
    final pace = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(
        input(periodSpent: 600, todaySpent: 50),
      ),
      dailyDiscretionary: {
        DateTime(2026, 10, 1): 100,
        DateTime(2026, 10, 3): 250,
        // A stored time of day still counts toward its calendar day.
        DateTime(2026, 10, 3, 18, 30): 200,
        DateTime(2026, 10, 5): 50,
      },
    )!;

    expect(pace.daysPassed, 5);
    expect(pace.totalDays, 30);
    expect(pace.cumulative, [100, 100, 550, 550, 600]);
    expect(pace.actualToDate, 600);
  });

  test('plans the period\'s discretionary money evenly over its days', () {
    // ₹1,000 already paid for bills; savings goal ₹500. Discretionary
    // money for the period = 3000 − 1000 − 500 = 1500.
    final pace = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(
        input(periodSpent: 1300, committedInPeriod: 1000, savings: 500),
      ),
      dailyDiscretionary: {DateTime(2026, 10, 2): 300},
    )!;

    expect(pace.plannedTotal, 1500);
    // Even pace to the end of day 5: 1500 × 5 ÷ 30.
    expect(pace.plannedToDate, 250);
    expect(pace.actualToDate, 300);
    expect(pace.aheadOfPlan, 50);
  });

  test('is only meaningful after a few days with some spending', () {
    final early = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(
        input(today: DateTime(2026, 10, 2), periodSpent: 40),
      ),
      dailyDiscretionary: {DateTime(2026, 10, 1): 40},
    )!;
    expect(early.isMeaningful, isFalse);

    final quiet = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(input()),
      dailyDiscretionary: const {},
    )!;
    expect(quiet.isMeaningful, isFalse);

    final enough = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(input(periodSpent: 40)),
      dailyDiscretionary: {DateTime(2026, 10, 1): 40},
    )!;
    expect(enough.isMeaningful, isTrue);
  });

  test('there is no pace outside the running period', () {
    final pace = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(input(today: DateTime(2026, 9, 20))),
      dailyDiscretionary: const {},
    );
    expect(pace, isNull);
  });

  test('a daylight-saving day is still one day', () {
    // Europe moves clocks on 25 Oct 2026; calendar stepping keeps one
    // entry per date whatever the device time zone.
    final pace = SpendingPaceBuilder.build(
      safeToSpend: calculator.calculate(
        input(today: DateTime(2026, 10, 27), periodSpent: 70),
      ),
      dailyDiscretionary: {
        DateTime(2026, 10, 25): 30,
        DateTime(2026, 10, 26): 40,
      },
    )!;
    expect(pace.cumulative.length, 27);
    expect(pace.cumulative[24], 30);
    expect(pace.cumulative[25], 70);
  });
}
