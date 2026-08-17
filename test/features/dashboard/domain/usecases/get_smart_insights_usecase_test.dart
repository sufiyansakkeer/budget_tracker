import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/smart_insight_entity.dart';
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

  test('reports critical budget overspending with amount', () {
    final result = useCase(
      summary(status: BudgetStatus.overBudget, expectedOverspending: 3000),
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
}
