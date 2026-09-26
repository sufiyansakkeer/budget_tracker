import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';

ExpenseEntity expense({
  required String id,
  required double amount,
  required String categoryId,
  required DateTime date,
}) => ExpenseEntity(
  id: id,
  budgetId: 'b1',
  amount: amount,
  categoryId: categoryId,
  date: date,
  time: date,
  createdAt: date,
  updatedAt: date,
);

void main() {
  const service = AnalyticsService();
  final categories = defaultCategories;

  // A 7-day range: 8–14 Sep 2026. Previous period: 1–7 Sep 2026.
  final range = ReportRange(
    start: DateTime(2026, 9, 8),
    end: DateTime(2026, 9, 14),
    period: ReportPeriod.custom,
  );

  group('calculateCategoryComparison', () {
    test('returns empty when there is nothing in either period', () {
      final result = service.calculateCategoryComparison(
        expenses: const [],
        range: range,
        categories: categories,
      );
      expect(result, isEmpty);
    });

    test(
      'compares each category against the preceding equal-length window',
      () {
        final current = [
          expense(
            id: 'c1',
            amount: 600,
            categoryId: 'food',
            date: DateTime(2026, 9, 9),
          ),
          expense(
            id: 'c2',
            amount: 100,
            categoryId: 'travel',
            date: DateTime(2026, 9, 10),
          ),
        ];
        final previous = [
          expense(
            id: 'p1',
            amount: 500,
            categoryId: 'food',
            date: DateTime(2026, 9, 3),
          ),
          expense(
            id: 'p2',
            amount: 400,
            categoryId: 'fuel',
            date: DateTime(2026, 9, 4),
          ),
        ];

        final result = service.calculateCategoryComparison(
          expenses: current,
          range: range,
          categories: categories,
          comparisonExpenses: [...current, ...previous],
        );

        // Ordered by absolute change: fuel (−400), food (+100), travel (+100).
        expect(result.first.categoryId, 'fuel');
        expect(result.first.currentAmount, 0);
        expect(result.first.previousAmount, 400);
        expect(result.first.difference, -400);
        expect(result.first.isGone, isTrue);

        final food = result.firstWhere((c) => c.categoryId == 'food');
        expect(food.currentAmount, 600);
        expect(food.previousAmount, 500);
        expect(food.difference, 100);
        expect(food.percentageChange, closeTo(20, 0.001));
        expect(food.isNew, isFalse);

        final travel = result.firstWhere((c) => c.categoryId == 'travel');
        expect(travel.previousAmount, 0);
        expect(travel.isNew, isTrue);
        expect(travel.percentageChange, isNull);
      },
    );

    test('ignores expenses outside both windows', () {
      final result = service.calculateCategoryComparison(
        expenses: [
          expense(
            id: 'inside',
            amount: 50,
            categoryId: 'food',
            date: DateTime(2026, 9, 8),
          ),
          expense(
            id: 'too-old',
            amount: 999,
            categoryId: 'food',
            date: DateTime(2026, 8, 20),
          ),
          expense(
            id: 'future',
            amount: 999,
            categoryId: 'food',
            date: DateTime(2026, 9, 20),
          ),
        ],
        range: range,
        categories: categories,
      );

      expect(result.single.categoryId, 'food');
      expect(result.single.currentAmount, 50);
      expect(result.single.previousAmount, 0);
    });

    test('is included in buildReportData', () {
      final data = service.buildReportData(
        range: range,
        filteredExpenses: [
          expense(
            id: 'c1',
            amount: 600,
            categoryId: 'food',
            date: DateTime(2026, 9, 9),
          ),
        ],
        categories: categories,
        filter: const ExpenseHistoryFilter(),
        comparisonExpenses: [
          expense(
            id: 'p1',
            amount: 500,
            categoryId: 'food',
            date: DateTime(2026, 9, 3),
          ),
        ],
      );
      expect(data.categoryComparison.single.difference, 100);
    });
  });
}
