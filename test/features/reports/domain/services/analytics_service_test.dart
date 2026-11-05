import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/default_categories.dart';
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
  final categories = defaultCategories;

  test('an expense whose category is gone is drawn in the Others colour', () {
    final others = categories.firstWhere((c) => c.id == fallbackCategoryId);
    final result = service.calculateCategoryAnalytics(
      expenses: [expense(id: '1', categoryId: 'deleted-category')],
      categories: categories,
    );
    expect(result.single.colorHex, others.colorHex);
  });

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
      expect(analytics.highestSpendingWeekday, DateTime(2026, 8, 1).weekday);
    });
  });

  // UX-112: run under a time zone with daylight saving to mean anything:
  // TZ=America/New_York flutter test (US clocks change 8 Mar and 1 Nov
  // 2026; Europe's 29 Mar and 25 Oct fall inside the same ranges).
  group('UX-112: day counts across a clock change', () {
    for (final (name, start, end, days) in [
      ('spring forward', DateTime(2026, 3, 1), DateTime(2026, 3, 31), 31),
      ('fall back', DateTime(2026, 10, 1), DateTime(2026, 11, 30), 61),
    ]) {
      test('$name: every calendar day, once, at midnight', () {
        final range = ReportRange(
          start: start,
          end: end,
          period: ReportPeriod.custom,
        );
        expect(range.dayCount, days);
        final points = service.calculateDailySpending(
          expenses: const [],
          range: range,
        );
        expect(points, hasLength(days));
        for (var i = 0; i < points.length; i++) {
          final date = points[i].date;
          expect(date, DateTime(start.year, start.month, start.day + i));
          expect(date.hour, 0, reason: '$date');
        }
        expect(points.last.date, end);
      });
    }
  });

  group('calculateTrend', () {
    test('a range that ends today compares completed days only', () {
      // On 2 August, with spending on the 1st and none yet today: today is
      // still being spent, so it is not "a better second half".
      final trend = AnalyticsService(clock: () => DateTime(2026, 8, 2, 10))
          .calculateTrend(
            expenses: [
              ExpenseEntity(
                id: 'a',
                budgetId: 'b',
                amount: 500,
                categoryId: 'food',
                date: DateTime(2026, 8, 1),
                time: DateTime(2026, 8, 1, 12),
                createdAt: DateTime(2026, 8, 1),
                updatedAt: DateTime(2026, 8, 1),
              ),
            ],
            range: ReportRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 2),
              period: ReportPeriod.thisMonth,
            ),
          );
      expect(trend.isImproving, isFalse);
    });

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
      expect(data.categoryAnalytics.length, 1);
      expect(data.isEmpty, false);
    });
  });
}
