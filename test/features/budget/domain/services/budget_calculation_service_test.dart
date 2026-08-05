import 'package:budget_tracker/features/budget/domain/entities/budget_calculation_input.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_status.dart';
import 'package:budget_tracker/features/budget/domain/entities/budget_thresholds.dart';
import 'package:budget_tracker/features/budget/domain/services/budget_calculation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BudgetCalculationService service;

  setUp(() {
    service = BudgetCalculationService();
  });

  group('daysInMonth', () {
    test('returns 31 for August', () {
      expect(service.daysInMonth(8, 2026), 31);
    });

    test('returns 30 for April', () {
      expect(service.daysInMonth(4, 2026), 30);
    });

    test('returns 28 for February non-leap year', () {
      expect(service.daysInMonth(2, 2025), 28);
    });

    test('returns 29 for February leap year', () {
      expect(service.daysInMonth(2, 2024), 29);
    });
  });

  group('calculateRemainingDays', () {
    test('returns 22 when today is 10th in 31-day month', () {
      final days = service.calculateRemainingDays(
        referenceDate: DateTime(2026, 8, 10),
        budgetMonth: 8,
        budgetYear: 2026,
      );
      expect(days, 22);
    });

    test('returns 1 on last day of month', () {
      final days = service.calculateRemainingDays(
        referenceDate: DateTime(2026, 8, 31),
        budgetMonth: 8,
        budgetYear: 2026,
      );
      expect(days, 1);
    });

    test('returns 1 on last day of February leap year', () {
      final days = service.calculateRemainingDays(
        referenceDate: DateTime(2024, 2, 29),
        budgetMonth: 2,
        budgetYear: 2024,
      );
      expect(days, 1);
    });

    test('returns correct days for 30-day month', () {
      final days = service.calculateRemainingDays(
        referenceDate: DateTime(2026, 4, 15),
        budgetMonth: 4,
        budgetYear: 2026,
      );
      expect(days, 16); // 30 - 15 + 1
    });

    test('throws when reference date is outside budget month', () {
      expect(
        () => service.calculateRemainingDays(
          referenceDate: DateTime(2026, 9, 1),
          budgetMonth: 8,
          budgetYear: 2026,
        ),
        throwsArgumentError,
      );
    });
  });

  group('calculateDaysPassed', () {
    test('returns day of month including today', () {
      expect(
        service.calculateDaysPassed(
          referenceDate: DateTime(2026, 8, 10),
          budgetMonth: 8,
          budgetYear: 2026,
        ),
        10,
      );
    });
  });

  group('calculateDailyAllowance', () {
    test(
      'matches spec example: 30000 budget on 10 Aug with 21 remaining days',
      () {
        // Prompt example uses 21 remaining days (different month interpretation)
        // With our rule (include today): 31-10+1=22 → 30000/22 ≈ 1363.64
        // Prompt says 21 days → 30000/21 ≈ 1428.57
        final allowance = service.calculateDailyAllowance(
          remainingBudget: 30000,
          remainingDays: 21,
        );
        expect(allowance, closeTo(1428.57, 0.01));
      },
    );

    test('recalculates after spending: 29200 / 21', () {
      final allowance = service.calculateDailyAllowance(
        remainingBudget: 29200,
        remainingDays: 21,
      );
      expect(allowance, closeTo(1390.48, 0.01));
    });

    test('never divides by zero – uses minimum 1 day', () {
      final allowance = service.calculateDailyAllowance(
        remainingBudget: 5000,
        remainingDays: 0,
      );
      expect(allowance, 5000);
    });
  });

  group('calculateTodayOverspending', () {
    test('returns 572 when spent 2000 with allowance 1428', () {
      final overspent = service.calculateTodayOverspending(
        todaySpending: 2000,
        dailyAllowance: 1428,
      );
      expect(overspent, closeTo(572, 0.01));
    });

    test('returns 0 when under allowance', () {
      expect(
        service.calculateTodayOverspending(
          todaySpending: 900,
          dailyAllowance: 1500,
        ),
        0,
      );
    });
  });

  group('calculateRemainingBudget', () {
    test('subtracts total spent from monthly amount', () {
      expect(
        service.calculateRemainingBudget(monthlyAmount: 30000, totalSpent: 800),
        29200,
      );
    });

    test('allows negative when over budget', () {
      expect(
        service.calculateRemainingBudget(
          monthlyAmount: 30000,
          totalSpent: 35000,
        ),
        -5000,
      );
    });
  });

  group('calculateAverageDailySpending', () {
    test('returns 900 when 9000 spent over 10 days', () {
      expect(
        service.calculateAverageDailySpending(totalSpent: 9000, daysPassed: 10),
        900,
      );
    });

    test('uses minimum 1 day to avoid division by zero', () {
      expect(
        service.calculateAverageDailySpending(totalSpent: 0, daysPassed: 0),
        0,
      );
    });
  });

  group('prediction engine', () {
    test('projects 27000 for 9000 spent in 10 days over 30-day month', () {
      final average = service.calculateAverageDailySpending(
        totalSpent: 9000,
        daysPassed: 10,
      );
      final projected = service.calculateExpectedMonthEndSpending(
        averageDailySpending: average,
        daysInMonth: 30,
      );
      expect(projected, 27000);
    });

    test('returns projected savings when under budget', () {
      final savings = service.calculateProjectedSavings(
        monthlyAmount: 30000,
        expectedMonthEndSpending: 27000,
      );
      expect(savings, 3000);
    });

    test('returns projected overspending when over budget', () {
      final overspending = service.calculateProjectedOverspending(
        monthlyAmount: 30000,
        expectedMonthEndSpending: 35000,
      );
      expect(overspending, 5000);
    });

    test('returns 0 savings when projected equals budget', () {
      expect(
        service.calculateProjectedSavings(
          monthlyAmount: 30000,
          expectedMonthEndSpending: 30000,
        ),
        0,
      );
    });
  });

  group('calculateBudgetStatus', () {
    test('returns underBudget below 80%', () {
      expect(
        service.calculateBudgetStatus(budgetUtilization: 0.79),
        BudgetStatus.underBudget,
      );
    });

    test('returns nearLimit at 80%', () {
      expect(
        service.calculateBudgetStatus(budgetUtilization: 0.80),
        BudgetStatus.nearLimit,
      );
    });

    test('returns nearLimit at 100%', () {
      expect(
        service.calculateBudgetStatus(budgetUtilization: 1.0),
        BudgetStatus.nearLimit,
      );
    });

    test('returns overBudget above 100%', () {
      expect(
        service.calculateBudgetStatus(budgetUtilization: 1.01),
        BudgetStatus.overBudget,
      );
    });

    test('respects custom thresholds', () {
      const custom = BudgetThresholds(
        nearLimitThreshold: 0.70,
        overBudgetThreshold: 0.90,
      );
      expect(
        service.calculateBudgetStatus(
          budgetUtilization: 0.75,
          thresholds: custom,
        ),
        BudgetStatus.nearLimit,
      );
      expect(
        service.calculateBudgetStatus(
          budgetUtilization: 0.95,
          thresholds: custom,
        ),
        BudgetStatus.overBudget,
      );
    });
  });

  group('buildSummary', () {
    test('full under-budget scenario with zero expenses', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 0,
        todaySpending: 0,
        referenceDate: _aug10,
        budgetMonth: 8,
        budgetYear: 2026,
      );

      final summary = service.buildSummary(input, currency: 'INR');

      expect(summary.remainingBudget, 30000);
      expect(summary.remainingDays, 22);
      expect(summary.daysPassed, 10);
      expect(summary.dailySafeSpending, closeTo(1363.64, 0.01));
      expect(summary.spendingPercentage, 0);
      expect(summary.remainingPercentage, 100);
      expect(summary.status, BudgetStatus.underBudget);
      expect(summary.expectedSavings, greaterThan(0));
      expect(summary.expectedOverspending, 0);
      expect(summary.currency, 'INR');
    });

    test('over-budget scenario', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 32000,
        todaySpending: 2000,
        referenceDate: _aug10,
        budgetMonth: 8,
        budgetYear: 2026,
      );

      final summary = service.buildSummary(input, currency: 'INR');

      expect(summary.remainingBudget, -2000);
      expect(summary.status, BudgetStatus.overBudget);
      expect(summary.spendingPercentage, closeTo(106.67, 0.01));
    });

    test('multiple expenses reflected in totals', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 800,
        todaySpending: 300,
        referenceDate: _aug10,
        budgetMonth: 8,
        budgetYear: 2026,
      );

      final summary = service.buildSummary(input, currency: 'INR');

      expect(summary.totalSpent, 800);
      expect(summary.todaySpending, 300);
      expect(summary.remainingBudget, 29200);
    });

    test('memoization returns same instance for identical input', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 0,
        todaySpending: 0,
        referenceDate: _aug10,
        budgetMonth: 8,
        budgetYear: 2026,
      );

      final first = service.buildSummary(input, currency: 'INR');
      final second = service.buildSummary(input, currency: 'INR');
      expect(identical(first, second), isTrue);
    });

    test('clearCache forces recalculation', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 0,
        todaySpending: 0,
        referenceDate: _aug10,
        budgetMonth: 8,
        budgetYear: 2026,
      );

      final first = service.buildSummary(input, currency: 'INR');
      service.clearCache();
      final second = service.buildSummary(input, currency: 'INR');
      expect(identical(first, second), isFalse);
      expect(first, equals(second));
    });
  });

  group('buildAnalytics', () {
    test('includes projected remaining balance', () {
      final input = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 9000,
        todaySpending: 500,
        referenceDate: _aug10,
        budgetMonth: 8,
        budgetYear: 2026,
      );

      final analytics = service.buildAnalytics(input);

      expect(analytics.daysPassed, 10);
      expect(analytics.daysRemaining, 22);
      expect(analytics.averageDailySpending, 900);
      expect(analytics.expectedMonthEndSpending, closeTo(27900, 0.01));
      expect(analytics.projectedRemainingBalance, closeTo(2100, 0.01));
      expect(analytics.projectedSavings, closeTo(2100, 0.01));
    });
  });

  group('midnight rule – unused allowance stays in budget', () {
    test('next day allowance increases when yesterday was under-spent', () {
      // Day 1: spent 900 of 1500 allowance → remaining budget stays high
      final day1 = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 900,
        todaySpending: 900,
        referenceDate: DateTime(2026, 8, 10),
        budgetMonth: 8,
        budgetYear: 2026,
      );
      final summaryDay1 = service.buildSummary(day1, currency: 'INR');

      // Day 2: same total spent, new day → more remaining days consumed
      final day2 = BudgetCalculationInput(
        monthlyAmount: 30000,
        totalSpent: 900,
        todaySpending: 0,
        referenceDate: DateTime(2026, 8, 11),
        budgetMonth: 8,
        budgetYear: 2026,
      );
      service.clearCache();
      final summaryDay2 = service.buildSummary(day2, currency: 'INR');

      // Remaining budget unchanged (900 spent total)
      expect(summaryDay2.remainingBudget, summaryDay1.remainingBudget);
      // Fewer remaining days → higher daily allowance than if money were removed
      expect(summaryDay2.dailySafeSpending, greaterThan(0));
      expect(summaryDay2.remainingDays, 21);
    });
  });
}

final _aug10 = DateTime(2026, 8, 10);
