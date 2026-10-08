import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/smart_insight_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_smart_insights_usecase.dart';

void main() {
  const useCase = GetSmartInsightsUseCase();

  BudgetSummaryEntity summary({
    double monthly = 30000,
    double spent = 8500,
    int remaining = 12,
    double safe = 1240,
    double average = 472,
    double expectedSavings = 11500,
    double expectedOverspending = 0,
    double todayOverspending = 0,
    BudgetStatus status = BudgetStatus.underBudget,
  }) {
    return BudgetSummaryEntity(
      monthlyAmount: monthly,
      remainingBudget: monthly - spent,
      totalSpent: spent,
      todaySpending: 0,
      remainingDays: remaining,
      daysPassed: 18,
      dailySafeSpending: safe,
      budgetUtilization: monthly == 0 ? 0 : spent / monthly,
      spendingPercentage: monthly == 0 ? 0 : spent / monthly * 100,
      remainingPercentage: monthly == 0 ? 0 : (monthly - spent) / monthly * 100,
      averageDailySpending: average,
      expectedPeriodEndSpending: spent + (average * remaining),
      expectedSavings: expectedSavings,
      expectedOverspending: expectedOverspending,
      todayOverspending: todayOverspending,
      status: status,
      currency: 'INR',
      startDate: DateTime(2026, 8),
      endDate: DateTime(2026, 8, 31),
    );
  }

  test('returns a positive savings insight when there are no expenses', () {
    final result = useCase(
      summary(spent: 0, average: 0, expectedSavings: 30000),
    );
    expect(result.first.id, 'on_track_savings');
    expect(result.first.type, InsightType.positive);
  });

  test('reports today overspending and its amount', () {
    final result = useCase(summary(todayOverspending: 450));
    final insight = result.firstWhere((i) => i.id == 'today_overspending');
    expect(insight.type, InsightType.warning);
    expect(insight.message, contains('₹450'));
  });

  test('reports positive spending pace below safe allowance', () {
    final result = useCase(summary(average: 400, safe: 500));
    expect(result.first.id, 'spending_pace_under');
    expect(result.first.type, InsightType.positive);
    expect(result.first.message, contains('₹100'));
  });

  test('reports projected overspending', () {
    final result = useCase(
      summary(expectedSavings: 0, expectedOverspending: 2500),
    );
    expect(result.first.id, 'projected_overspending');
    expect(result.first.message, contains('₹2,500'));
  });

  test('reports projected savings', () {
    final result = useCase(summary(expectedSavings: 2000));
    expect(result.any((i) => i.id == 'on_track_savings'), isTrue);
  });

  test('reports critical budget overspending with the actual amount', () {
    final result = useCase(
      summary(
        spent: 33000,
        status: BudgetStatus.overBudget,
        expectedSavings: 0,
        expectedOverspending: 4500,
      ),
    );
    expect(result.first.id, 'over_budget');
    expect(result.first.type, InsightType.negative);
    expect(result.first.message, contains('₹3,000'));
  });

  test('returns under-budget positive insight when no pace data exists', () {
    final result = useCase(summary(average: 0, expectedSavings: 0));
    expect(result.any((i) => i.id == 'under_budget'), isTrue);
  });

  test('handles zero remaining days without crashing', () {
    final result = useCase(
      summary(remaining: 0, average: 500, expectedSavings: 0),
    );
    expect(result, isNotEmpty);
    expect(result.every((i) => !i.message.contains('NaN')), isTrue);
  });

  test('returns an informational insight when there is no budget', () {
    final result = useCase(summary(monthly: 0, spent: 0, expectedSavings: 0));
    expect(result, hasLength(1));
    expect(result.first.id, 'no_budget');
    expect(result.first.type, InsightType.info);
  });

  test('falls back to a real-data general insight for empty activity', () {
    final result = useCase(summary(average: 0, expectedSavings: 0, spent: 0));
    expect(result.first.id, 'under_budget');
    expect(result.first.type, InsightType.positive);
  });

  group('with the safe-to-spend engine result', () {
    final calculator = SafeToSpendCalculator(BudgetCalculationService());

    /// Aug 2026 budget on day 19: 18 completed days, 13 left incl. today.
    SafeToSpendEntity engine({required double spent, double bills = 0}) {
      return calculator.calculate(
        SafeToSpendInput(
          budgetId: 'aug',
          budgetName: 'August',
          currency: 'INR',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          today: DateTime(2026, 8, 19),
          budgetAmount: 30000,
          periodSpent: spent,
          todaySpent: 0,
          commitments: [
            if (bills > 0)
              CommitmentOccurrence(
                billId: 'rent',
                title: 'Rent',
                amount: bills,
                dueDate: DateTime(2026, 8, 25),
              ),
          ],
        ),
      );
    }

    BudgetDailyLimitEntity overLimit(String id) => BudgetDailyLimitEntity(
      budgetId: id,
      budgetName: 'Budget $id',
      dailyLimit: 100,
      spentToday: 150,
      remainingToday: 0,
      exceededToday: 50,
      progress: 1,
      isOverLimit: true,
      status: SpendingTargetStatus.exceeded,
      budgetStatus: BudgetStatus.underBudget,
      budgetUtilization: 0.3,
      monthlyAmount: 30000,
      totalSpent: 9000,
      remainingBudget: 21000,
      remainingDays: 13,
      weeklyTarget: 700,
      weeklySpent: 900,
      weeklyRemaining: 0,
      weeklyExceeded: 200,
      weeklyProgress: 1,
      weeklyStatus: SpendingTargetStatus.exceeded,
      currency: 'INR',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );

    const oldFormulaIds = {
      'today_overspending',
      'projected_overspending',
      'on_track_savings',
      'spending_pace_under',
      'spending_pace_over',
    };

    test('drops the bill-blind summary insights', () {
      final result = useCase(
        summary(
          todayOverspending: 450,
          expectedSavings: 0,
          expectedOverspending: 2500,
          average: 400,
          safe: 500,
        ),
        safeToSpend: engine(spent: 9000),
      );
      expect(
        result.map((i) => i.id).toSet().intersection(oldFormulaIds),
        isEmpty,
      );
    });

    test('warns once when the forecast runs short of what is protected', () {
      // 1000/day: raw 30000 − 18000 − 5000 = 7000; next 13 days 13000.
      final result = useCase(
        summary(expectedSavings: 2000),
        safeToSpend: engine(spent: 18000, bills: 5000),
      );
      final short = result.where((i) => i.id == 'safe_spend_forecast_short');
      expect(short, hasLength(1));
      expect(short.single.type, InsightType.warning);
      expect(short.single.message, contains('₹1,000 a day'));
      expect(short.single.message, contains('₹6,000 short'));
      expect(short.single.message, contains('bills and money set aside'));
      expect(result.any((i) => i.id == 'on_track_savings'), isFalse);
    });

    test('a healthy forecast is one positive insight', () {
      // 500/day: raw 30000 − 9000 − 2200 = 18800; next 13 days 6500.
      final result = useCase(
        summary(expectedSavings: 0, expectedOverspending: 2500),
        safeToSpend: engine(spent: 9000, bills: 2200),
      );
      final ok = result.where((i) => i.id == 'safe_spend_forecast_ok');
      expect(ok, hasLength(1));
      expect(ok.single.type, InsightType.positive);
      expect(ok.single.message, contains('₹12,300 free to spend'));
      expect(result.any((i) => i.id == 'projected_overspending'), isFalse);
    });

    test("drops the active budget's per-budget insights, keeps others", () {
      final result = useCase(
        summary(),
        budgetDailyLimits: [overLimit('aug'), overLimit('other')],
        safeToSpend: engine(spent: 9000),
      );
      final ids = result.map((i) => i.id).toList();
      expect(ids, contains('per_budget_over_other'));
      expect(ids, isNot(contains('per_budget_over_aug')));
      expect(ids, isNot(contains('per_budget_weekly_over_aug')));
    });

    test('without the engine result the per-budget insights are unchanged', () {
      final result = useCase(
        summary(),
        budgetDailyLimits: [overLimit('aug'), overLimit('other')],
      );
      final ids = result.map((i) => i.id).toList();
      expect(
        ids,
        containsAll(['per_budget_over_aug', 'per_budget_over_other']),
      );
    });
  });
}
