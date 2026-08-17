import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';

ExpenseEntity expense({
  required String id,
  double amount = 100,
  String categoryId = 'food',
  DateTime? date,
  List<String> tags = const [],
}) {
  final d = date ?? DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    budgetId: 'budget-1',
    amount: amount,
    categoryId: categoryId,
    date: d,
    time: d,
    tags: tags,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  const service = AnalyticsService();
  const categories = defaultCategories;

  group('calculateOverview', () {
    test('returns empty for no expenses', () {
      final overview = service.calculateOverview(
        expenses: const [],
        dayCount: 30,
      );
      expect(overview.totalSpending, 0);
      expect(overview.totalTransactions, 0);
      expect(overview.averageDailySpending, 0);
    });

    test('computes correct summary metrics', () {
      final overview = service.calculateOverview(
        expenses: [
          expense(id: '1', amount: 100),
          expense(id: '2', amount: 300),
          expense(id: '3', amount: 200),
        ],
        dayCount: 10,
      );
      expect(overview.totalSpending, 600);
      expect(overview.totalTransactions, 3);
      expect(overview.averageDailySpending, 60);
      expect(overview.averageTransactionAmount, 200);
      expect(overview.highestExpense, 300);
      expect(overview.lowestExpense, 100);
    });
  });

  group('calculateDailySpending', () {
    test('zero-fills every day in the range', () {
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 3),
        period: ReportPeriod.custom,
      );
      final points = service.calculateDailySpending(
        expenses: [expense(id: '1', amount: 50, date: DateTime(2026, 8, 2))],
        range: range,
      );
      expect(points.length, 3);
      expect(points[0].amount, 0);
      expect(points[1].amount, 50);
      expect(points[2].amount, 0);
    });
  });

  group('calculateCategorySlices', () {
    test('returns empty for no expenses', () {
      final slices = service.calculateCategorySlices(
        expenses: const [],
        categories: categories,
      );
      expect(slices, isEmpty);
    });

    test('computes percentages and sorts by amount descending', () {
      final slices = service.calculateCategorySlices(
        expenses: [
          expense(id: '1', amount: 300, categoryId: 'food'),
          expense(id: '2', amount: 100, categoryId: 'grocery'),
        ],
        categories: categories,
      );
      expect(slices.length, 2);
      expect(slices.first.categoryId, 'food');
      expect(slices.first.percentage, 75);
      expect(slices.last.percentage, 25);
    });
  });

  group('calculateCategoryAnalytics', () {
    test('returns empty for no expenses', () {
      final result = service.calculateCategoryAnalytics(
        expenses: const [],
        categories: categories,
      );
      expect(result, isEmpty);
    });

    test('aggregates per-category stats sorted by total', () {
      final result = service.calculateCategoryAnalytics(
        expenses: [
          expense(id: '1', amount: 100, categoryId: 'food'),
          expense(id: '2', amount: 200, categoryId: 'food'),
          expense(id: '3', amount: 50, categoryId: 'grocery'),
        ],
        categories: categories,
      );
      // food total 300, grocery total 50
      expect(result.length, 2);
      expect(result.first.categoryId, 'food');
      expect(result.first.totalAmount, 300);
      expect(result.first.transactionCount, 2);
      expect(result.first.averageTransaction, 150);
      expect(result.first.highestTransaction, 200);
      expect(result.first.lowestTransaction, 100);
      expect(result.first.percentageOfTotal, 300 / 350 * 100);
    });
  });

  group('calculateTimeAnalytics', () {
    test('returns empty for no expenses', () {
      final analytics = service.calculateTimeAnalytics(
        expenses: const [],
        range: ReportRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
          period: ReportPeriod.thisMonth,
        ),
      );
      expect(analytics.weekdaySpending, 0);
      expect(analytics.weekendSpending, 0);
    });

    test('classifies weekday vs weekend spending', () {
      // 2026-08-03 is a Monday (weekday), 2026-08-01 is a Saturday (weekend).
      final analytics = service.calculateTimeAnalytics(
        expenses: [
          expense(id: '1', amount: 100, date: DateTime(2026, 8, 3)),
          expense(id: '2', amount: 200, date: DateTime(2026, 8, 1)),
        ],
        range: ReportRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
          period: ReportPeriod.thisMonth,
        ),
      );
      expect(analytics.weekdaySpending, 100);
      expect(analytics.weekendSpending, 200);
      expect(analytics.mostExpensiveDay, DateTime(2026, 8, 1));
    });
  });

  group('calculateTrend', () {
    test('returns empty for no expenses', () {
      final trend = service.calculateTrend(
        expenses: const [],
        range: ReportRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
          period: ReportPeriod.thisMonth,
        ),
      );
      expect(trend.dailyAverage, 0);
      expect(trend.growthRate, 0);
      expect(trend.isImproving, false);
    });

    test('computes daily/weekly/monthly averages', () {
      final trend = service.calculateTrend(
        expenses: [expense(id: '1', amount: 300, date: DateTime(2026, 8, 1))],
        range: ReportRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 30),
          period: ReportPeriod.thisMonth,
        ),
      );
      expect(trend.dailyAverage, 10); // 300 / 30
      expect(trend.weeklyAverage, 70);
      expect(trend.monthlyAverage, 300);
    });
  });

  group('calculateWeeklyComparison', () {
    test('computes difference and percentage change', () {
      final range = ReportRange(
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 9),
        period: ReportPeriod.thisWeek,
      );
      final comparison = service.calculateWeeklyComparison(
        expenses: [
          expense(id: '1', amount: 100, date: DateTime(2026, 8, 3)),
          expense(id: '2', amount: 50, date: DateTime(2026, 7, 27)),
        ],
        range: range,
      );
      expect(comparison.currentWeekSpending, 100);
      expect(comparison.previousWeekSpending, 50);
      expect(comparison.difference, 50);
      expect(comparison.percentageChange, 100);
    });
  });

  group('buildReportData', () {
    test('produces a complete ReportData snapshot', () {
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        period: ReportPeriod.thisMonth,
      );
      final data = service.buildReportData(
        range: range,
        filteredExpenses: [expense(id: '1', amount: 100, categoryId: 'food')],
        categories: categories,
        filter: const ExpenseHistoryFilter(),
      );
      expect(data.overview.totalSpending, 100);
      expect(data.dailySpending.length, 31);
      expect(data.categorySlices.length, 1);
      expect(data.categoryAnalytics.length, 1);
      expect(data.isEmpty, false);
    });
  });
}
