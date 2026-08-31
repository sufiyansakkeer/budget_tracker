import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_sort.dart';
import 'package:monivo/features/expenses/domain/usecases/group_expenses_usecase.dart';

ExpenseEntity _e({
  required String id,
  required double amount,
  required DateTime date,
  required DateTime time,
}) {
  return ExpenseEntity(
    id: id,
    budgetId: 'b1',
    amount: amount,
    categoryId: 'food',
    date: date,
    time: time,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  final grouper = const GroupExpensesUseCase();

  group('GroupExpensesUseCase — respects sort option', () {
    test('newestFirst — items within group sorted by date+time desc', () {
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
      final groups = grouper(expenses, sort: ExpenseSortOption.newestFirst);

      // Two groups: Aug 29 and Aug 28
      expect(groups.length, 2);

      // Aug 29 group: 10:00 before 06:00
      final aug29 = groups.firstWhere((g) => g.date == DateTime(2026, 8, 29));
      expect(aug29.expenses.map((e) => e.id), ['2', '1']);

      // Aug 28 group: single item
      final aug28 = groups.firstWhere((g) => g.date == DateTime(2026, 8, 28));
      expect(aug28.expenses.map((e) => e.id), ['3']);
    });

    test('oldestFirst — items within group sorted by date+time asc', () {
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
      ];
      final groups = grouper(expenses, sort: ExpenseSortOption.oldestFirst);

      final aug29 = groups.firstWhere((g) => g.date == DateTime(2026, 8, 29));
      // 06:00 before 10:00
      expect(aug29.expenses.map((e) => e.id), ['2', '1']);
    });

    test('highestAmount — items within group sorted by amount desc', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
        _e(
          id: '2',
          amount: 500,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 6),
        ),
      ];
      final groups = grouper(expenses, sort: ExpenseSortOption.highestAmount);

      final aug29 = groups.firstWhere((g) => g.date == DateTime(2026, 8, 29));
      expect(aug29.expenses.map((e) => e.amount), [500, 300, 100]);
    });

    test('lowestAmount — items within group sorted by amount asc', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
        _e(
          id: '2',
          amount: 500,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 10),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 6),
        ),
      ];
      final groups = grouper(expenses, sort: ExpenseSortOption.lowestAmount);

      final aug29 = groups.firstWhere((g) => g.date == DateTime(2026, 8, 29));
      expect(aug29.expenses.map((e) => e.amount), [100, 300, 500]);
    });

    test('groups are always in chronological descending order', () {
      final expenses = [
        _e(
          id: '1',
          amount: 100,
          date: DateTime(2026, 8, 27),
          time: DateTime(2026, 8, 27, 8),
        ),
        _e(
          id: '2',
          amount: 200,
          date: DateTime(2026, 8, 29),
          time: DateTime(2026, 8, 29, 8),
        ),
        _e(
          id: '3',
          amount: 300,
          date: DateTime(2026, 8, 28),
          time: DateTime(2026, 8, 28, 8),
        ),
      ];
      final groups = grouper(expenses, sort: ExpenseSortOption.highestAmount);

      // Groups should be: Aug 29, Aug 28, Aug 27 (newest first)
      expect(groups.length, 3);
      expect(groups[0].date, DateTime(2026, 8, 29));
      expect(groups[1].date, DateTime(2026, 8, 28));
      expect(groups[2].date, DateTime(2026, 8, 27));
    });
  });
}
