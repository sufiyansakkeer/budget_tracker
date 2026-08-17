import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/smart_insight_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/reports/domain/entities/category_analytics.dart';
import 'package:monivo/features/reports/domain/entities/report_data.dart';
import 'package:monivo/features/reports/domain/entities/report_overview.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/entities/spending_trend.dart';
import 'package:monivo/features/reports/domain/entities/time_analytics.dart';
import 'package:monivo/features/reports/domain/services/report_insight_generator.dart';

ExpenseEntity expense({
  required String id,
  double amount = 100,
  String categoryId = 'food',
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    budgetId: 'budget-1',
    amount: amount,
    categoryId: categoryId,
    date: d,
    time: d,
    createdAt: d,
    updatedAt: d,
  );
}

ReportData buildData({
  List<ExpenseEntity> expenses = const [],
  SpendingTrend? trend,
  List<CategoryAnalytics>? categoryAnalytics,
  TimeAnalytics? timeAnalytics,
  BudgetEntity? budget,
  double currentMonthSpent = 0,
  double currentMonthBudget = 0,
}) {
  return ReportData(
    range: ReportRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
      period: ReportPeriod.thisMonth,
    ),
    filteredExpenses: expenses,
    categories: defaultCategories,
    filter: const ExpenseHistoryFilter(),
    overview: expenses.isEmpty
        ? ReportOverview.empty
        : ReportOverview(
            totalSpending: expenses.fold<double>(0, (s, e) => s + e.amount),
            totalTransactions: expenses.length,
            averageDailySpending: 0,
            averageTransactionAmount: 0,
            highestExpense: 0,
            lowestExpense: 0,
          ),
    dailySpending: const [],
    spendingBuckets: const [],
    categorySlices: const [],
    categoryAnalytics: categoryAnalytics ?? const [],
    timeAnalytics: timeAnalytics ?? TimeAnalytics.empty,
    trend: trend ?? SpendingTrend.empty,
    currentBudget: budget,
    currentMonthSpent: currentMonthSpent,
    currentMonthBudget: currentMonthBudget,
  );
}

void main() {
  const generator = ReportInsightGenerator();

  test('returns no-data insight for empty report', () {
    final insights = generator.generate(buildData());
    expect(insights.length, 1);
    expect(insights.first.type, InsightType.info);
    expect(insights.first.message, contains('Add expenses'));
  });

  test('generates spending comparison insight when growth changes', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        trend: const SpendingTrend(
          dailyAverage: 10,
          weeklyAverage: 70,
          monthlyAverage: 300,
          growthRate: -0.2,
          consistencyScore: 0.5,
          isImproving: false,
        ),
      ),
    );
    expect(
      insights.any(
        (i) => i.id == 'spending_decreased' && i.type == InsightType.positive,
      ),
      true,
    );
  });

  test('generates top category insight', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        categoryAnalytics: const [
          CategoryAnalytics(
            categoryId: 'food',
            categoryName: 'Food',
            colorHex: '#FF6B6B',
            totalAmount: 100,
            transactionCount: 1,
            averageTransaction: 100,
            highestTransaction: 100,
            lowestTransaction: 100,
            percentageOfTotal: 37,
          ),
        ],
      ),
    );
    expect(insights.any((i) => i.id == 'top_category'), true);
    expect(
      insights.firstWhere((i) => i.id == 'top_category').message,
      contains('Food accounts for 37%'),
    );
  });

  test('generates highest spending day insight', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        timeAnalytics: const TimeAnalytics(
          highestSpendingWeekday: 5,
          weekdaySpending: 100,
          weekendSpending: 0,
        ),
      ),
    );
    expect(insights.any((i) => i.id == 'highest_spending_day'), true);
  });

  test('generates weekend spending insight when weekend ratio is high', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        timeAnalytics: const TimeAnalytics(
          weekdaySpending: 40,
          weekendSpending: 60,
        ),
      ),
    );
    expect(insights.any((i) => i.id == 'weekend_spending'), true);
  });

  test('generates projected savings insight', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        budget: BudgetEntity(
          id: '1',
          name: 'Test',
          monthlyAmount: 1000,
          remainingAmount: 800,
          currency: '₹',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
        currentMonthSpent: 500,
        currentMonthBudget: 1000,
      ),
    );
    expect(
      insights.any(
        (i) => i.id == 'projected_savings' && i.type == InsightType.positive,
      ),
      true,
    );
  });

  test('generates budget exceeded insight', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        budget: BudgetEntity(
          id: '1',
          name: 'Test',
          monthlyAmount: 1000,
          remainingAmount: 0,
          currency: '₹',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
        currentMonthSpent: 1200,
        currentMonthBudget: 1000,
      ),
    );
    expect(
      insights.any(
        (i) => i.id == 'budget_exceeded' && i.type == InsightType.negative,
      ),
      true,
    );
  });

  test('generates improving trend insight', () {
    final insights = generator.generate(
      buildData(
        expenses: [expense(id: '1')],
        trend: const SpendingTrend(
          dailyAverage: 10,
          weeklyAverage: 70,
          monthlyAverage: 300,
          growthRate: 0,
          consistencyScore: 0.5,
          isImproving: true,
        ),
      ),
    );
    expect(insights.any((i) => i.id == 'trend_improving'), true);
  });
}
