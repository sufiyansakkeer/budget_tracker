import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';

// The blueprint's data story (docs/design/monivo-blueprint.html): a ₹60,000
// budget for 1–31 Oct 2026, seen on 8 Oct (24 days left). ₹34,897 spent,
// ₹570 of it today; ₹1,850 of bills and a ₹3,000 savings goal set aside, so
// ₹20,253 is free and today's target is 20,823 ÷ 24 = ₹867.625.
final _today = DateTime(2026, 10, 8);

SafeToSpendInput _input({
  DateTime? today,
  double periodSpent = 34897,
  double todaySpent = 570,
  double? savings = 3000,
}) => SafeToSpendInput(
  budgetId: 'b1',
  budgetName: 'October',
  currency: 'INR',
  startDate: DateTime(2026, 10, 1),
  endDate: DateTime(2026, 10, 31),
  today: today ?? _today,
  budgetAmount: 60000,
  periodSpent: periodSpent,
  todaySpent: todaySpent,
  commitments: [
    CommitmentOccurrence(
      billId: 'rent',
      title: 'Rent',
      amount: 1850,
      dueDate: DateTime(2026, 10, 20),
      isOverdue: false,
    ),
  ],
  savingsTarget: savings,
);

// Spending on each completed day, 1–7 Oct.
final _history = {
  DateTime(2026, 10, 1): 3900.0,
  DateTime(2026, 10, 2): 6200.0,
  DateTime(2026, 10, 3): 5050.0,
  DateTime(2026, 10, 4): 2900.0,
  DateTime(2026, 10, 5): 7100.0,
  DateTime(2026, 10, 6): 4600.0,
  DateTime(2026, 10, 7): 4577.0,
};

void main() {
  final calculator = SafeToSpendCalculator(BudgetCalculationService());

  group('preview (a draft expense today, before it is saved)', () {
    test('a zero draft gives the same result as calculate', () {
      expect(
        calculator.preview(_input(), draftToday: 0),
        calculator.calculate(_input()),
      );
    });

    test('keeps today\'s target and takes the draft from what is left', () {
      final before = calculator.calculate(_input());
      final after = calculator.preview(_input(), draftToday: 200);

      expect(after.dailySafeToSpend, before.dailySafeToSpend);
      expect(after.remainingToday, closeTo(97.625, 1e-9));
      expect(after.todaySpent, 770);
    });

    test('tomorrow\'s target is what tomorrow would be after saving it', () {
      final after = calculator.preview(_input(), draftToday: 390);
      // (20,253 − 390) ÷ 23
      expect(after.tomorrowIfNoMoreSpending, closeTo(863.6087, 1e-4));
      expect(
        after.tomorrowIfNoMoreSpending,
        calculator
            .calculate(_input(periodSpent: 35287, todaySpent: 960))
            .tomorrowIfNoMoreSpending,
      );
    });

    test('a draft past today\'s target reads as over today', () {
      final after = calculator.preview(_input(), draftToday: 400);
      expect(after.status, SafeToSpendStatus.overDailyAllowance);
      expect(after.overToday, closeTo(102.375, 1e-9));
    });

    test('a negative draft (an expense made smaller) adds back', () {
      final after = calculator.preview(_input(), draftToday: -70);
      expect(after.todaySpent, 500);
      expect(after.remainingToday, closeTo(367.625, 1e-9));
    });

    test('outside the period the draft is not this budget\'s spending', () {
      final ended = _input(today: DateTime(2026, 11, 2), todaySpent: 0);
      expect(
        calculator.preview(ended, draftToday: 500),
        calculator.calculate(ended),
      );
    });
  });

  group('targetSeries (each day\'s target, assuming today\'s set-asides)', () {
    test('one entry per day from the start of the period to today', () {
      final series = calculator.targetSeries(
        calculator.calculate(_input()),
        _history,
      );
      expect(series.map((d) => d.date), [
        for (var day = 1; day <= 8; day++) DateTime(2026, 10, day),
      ]);
    });

    test('matches the design\'s per-day targets', () {
      final series = calculator.targetSeries(
        calculator.calculate(_input()),
        _history,
      );
      const expected = [
        1779.03,
        1708.33,
        1553.45,
        1428.57,
        1374.07,
        1153.85,
        1016.00,
        867.62,
      ];
      for (var i = 0; i < expected.length; i++) {
        expect(series[i].target, closeTo(expected[i], 0.006), reason: '$i');
      }
    });

    test('today\'s entry is exactly the calculator\'s target and spending', () {
      final today = calculator.calculate(_input());
      final last = calculator.targetSeries(today, _history).last;
      expect(last.target, today.dailySafeToSpend);
      expect(last.spent, today.todayDiscretionary);
      expect(last.result, closeTo(297.625, 1e-9));
    });

    test('a day\'s result is target minus spent, negative when over', () {
      final series = calculator.targetSeries(
        calculator.calculate(_input()),
        _history,
      );
      // 2 Oct: target 1,708.33, spent 6,200.
      expect(series[1].spent, 6200);
      expect(series[1].result, closeTo(1708.33 - 6200, 0.006));
    });

    test('a day with no entry counts as nothing spent', () {
      final gap = Map.of(_history)..remove(DateTime(2026, 10, 4));
      final series = calculator.targetSeries(
        calculator.calculate(_input()),
        gap,
      );
      expect(series[3].spent, 0);
      // 4 Oct: (20,823 + 4,600 + 4,577 + 7,100) ÷ 28 = 1,325
      expect(series[3].target, closeTo(1325, 1e-9));
    });

    test('keys with a time of day still land on their date', () {
      final timed = {
        for (final e in _history.entries)
          e.key.add(const Duration(hours: 18, minutes: 30)): e.value,
      };
      final today = calculator.calculate(_input());
      expect(
        calculator.targetSeries(today, timed),
        calculator.targetSeries(today, _history),
      );
    });

    test('a target never goes below zero', () {
      final broke = calculator.calculate(
        _input(periodSpent: 59000, todaySpent: 0),
      );
      final series = calculator.targetSeries(broke, const {});
      expect(series.every((d) => d.target == 0), isTrue);
    });

    test('empty when the period is not running', () {
      final ended = calculator.calculate(
        _input(today: DateTime(2026, 11, 2), todaySpent: 0),
      );
      expect(calculator.targetSeries(ended, _history), isEmpty);
    });
  });
}
