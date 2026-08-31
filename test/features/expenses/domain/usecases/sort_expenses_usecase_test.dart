import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_sort.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';

ExpenseEntity _e({
  required String id,
  required double amount,
  required DateTime date,
  required DateTime time,
  String categoryId = 'food',
  String? note,
}) {
  return ExpenseEntity(
    id: id,
    budgetId: 'b1',
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: date,
    time: time,
    createdAt: date,
    updatedAt: date,
  );
}

const _categories = [
  ExpenseCategory(
    id: 'food',
    name: 'Food',
    icon: 'restaurant',
    colorHex: '#FF0000',
  ),
  ExpenseCategory(
    id: 'fuel',
    name: 'Fuel',
    icon: 'local_gas_station',
    colorHex: '#0000FF',
  ),
];

void main() {
  final sort = const SortExpensesUseCase();

  // ── Newest / Oldest ────────────────────────────────────────────

  group('newestFirst — uses date+time', () {
    test('orders by date then time descending', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 6),
        ),
        _e(
          id: '2',
          amount: 200,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 12),
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.newestFirst,
      );
      // Same day: 10:00 before 06:00; different day: 29th before 28th
      expect(result.map((e) => e.id), ['2', '1', '3']);
    });
  });

  group('oldestFirst — uses date+time', () {
    test('orders by date then time ascending', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
        _e(
          id: '2',
          amount: 200,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 6),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 12),
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.oldestFirst,
      );
      // Different day: 28th before 29th; Same day: 06:00 before 10:00
      expect(result.map((e) => e.id), ['3', '2', '1']);
    });
  });

  // ── Amount sorts ───────────────────────────────────────────────

  group('highestAmount', () {
    test('orders by amount descending', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
        _e(
          id: '2',
          amount: 800,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 6),
        ),
        _e(
          id: '4',
          amount: 500,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 12),
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.highestAmount,
      );
      expect(result.map((e) => e.amount), [800, 500, 300, 100]);
    });
  });

  group('lowestAmount', () {
    test('orders by amount ascending', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
        _e(
          id: '2',
          amount: 800,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 6),
        ),
        _e(
          id: '4',
          amount: 500,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 12),
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.lowestAmount,
      );
      expect(result.map((e) => e.amount), [100, 300, 500, 800]);
    });
  });

  // ── Category / Alphabetical ────────────────────────────────────

  group('category', () {
    test('orders by category name then date descending', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
          categoryId: 'food',
        ),
        _e(
          id: '2',
          amount: 200,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
          categoryId: 'fuel',
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 12),
          categoryId: 'food',
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.category,
      );
      // 'food' < 'fuel'; within food: 29th before 28th
      expect(result.map((e) => e.id), ['1', '3', '2']);
    });
  });

  group('alphabetical', () {
    test('orders by note then date descending', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
          note: 'Bread',
        ),
        _e(
          id: '2',
          amount: 200,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
          note: 'Apple',
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 12),
          note: 'Apple',
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.alphabetical,
      );
      // 'apple' < 'bread'; within apple: 29th before 28th
      expect(result.map((e) => e.id), ['2', '3', '1']);
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────

  group('edge cases', () {
    test('empty list returns empty', () {
      final result = sort(
        expenses: [],
        categories: _categories,
        sort: ExpenseSortOption.newestFirst,
      );
      expect(result, isEmpty);
    });

    test('single item returns as-is', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
      ];
      final result = sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.highestAmount,
      );
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('does not mutate original list', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
        _e(
          id: '2',
          amount: 200,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
      ];
      final original = List<ExpenseEntity>.from(expenses);
      sort(
        expenses: expenses,
        categories: _categories,
        sort: ExpenseSortOption.highestAmount,
      );
      expect(expenses, original);
    });
  });
}
