import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_sort.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/group_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';

ExpenseEntity expense({
  required String id,
  double amount = 100,
  String? categoryId = 'food',
  String? note,
  DateTime? date,
  List<String> tags = const [],
  String? receiptPath,
}) {
  final now = date ?? DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    budgetId: 'budget-1',
    amount: amount,
    categoryId: categoryId!,
    note: note,
    date: now,
    time: now,
    receiptImagePath: receiptPath,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const categories = defaultCategories;

  group('SearchExpensesUseCase', () {
    const useCase = SearchExpensesUseCase();

    test('returns all when query is empty', () {
      final expenses = [expense(id: '1', note: 'Lunch'), expense(id: '2')];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        query: '',
      );
      expect(result.length, 2);
    });

    test('matches by note case-insensitively', () {
      final expenses = [expense(id: '1', note: 'Lunch at cafe')];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        query: 'lunch',
      );
      expect(result.length, 1);
    });

    test('matches by category name', () {
      final expenses = [expense(id: '1', categoryId: 'grocery')];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        query: 'grocery',
      );
      expect(result.length, 1);
    });

    test('matches by tag', () {
      final expenses = [
        expense(id: '1', tags: ['work', 'lunch']),
      ];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        query: 'work',
      );
      expect(result.length, 1);
    });

    test('returns empty for no match', () {
      final expenses = [expense(id: '1', note: 'Lunch')];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        query: 'zzz',
      );
      expect(result, isEmpty);
    });
  });

  group('FilterExpensesUseCase', () {
    const useCase = FilterExpensesUseCase();

    test('returns all when filter inactive', () {
      final expenses = [expense(id: '1'), expense(id: '2')];
      final result = useCase(
        expenses: expenses,
        filter: const ExpenseHistoryFilter(),
      );
      expect(result.length, 2);
    });

    test('filters by category', () {
      final expenses = [
        expense(id: '1', categoryId: 'food'),
        expense(id: '2', categoryId: 'grocery'),
      ];
      final result = useCase(
        expenses: expenses,
        filter: const ExpenseHistoryFilter(categoryId: 'food'),
      );
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('filters by amount range', () {
      final expenses = [
        expense(id: '1', amount: 50),
        expense(id: '2', amount: 200),
        expense(id: '3', amount: 100),
      ];
      final result = useCase(
        expenses: expenses,
        filter: const ExpenseHistoryFilter(minAmount: 75, maxAmount: 150),
      );
      expect(result.length, 1);
      expect(result.first.id, '3');
    });

    test('filters by tags (all must match)', () {
      final expenses = [
        expense(id: '1', tags: ['a', 'b']),
        expense(id: '2', tags: ['a']),
      ];
      final result = useCase(
        expenses: expenses,
        filter: const ExpenseHistoryFilter(tags: ['a', 'b']),
      );
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('filters receipt only', () {
      final expenses = [
        expense(id: '1', receiptPath: '/x.jpg'),
        expense(id: '2'),
      ];
      final result = useCase(
        expenses: expenses,
        filter: const ExpenseHistoryFilter(receiptOnly: true),
      );
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('combines multiple filters (AND)', () {
      final expenses = [
        expense(id: '1', categoryId: 'food', amount: 80),
        expense(id: '2', categoryId: 'food', amount: 200),
        expense(id: '3', categoryId: 'grocery', amount: 90),
      ];
      final result = useCase(
        expenses: expenses,
        filter: const ExpenseHistoryFilter(categoryId: 'food', minAmount: 100),
      );
      expect(result.length, 1);
      expect(result.first.id, '2');
    });
  });

  group('SortExpensesUseCase', () {
    const useCase = SortExpensesUseCase();

    test('sorts newest first', () {
      final expenses = [
        expense(id: '1', date: DateTime(2026, 1, 1)),
        expense(id: '2', date: DateTime(2026, 3, 1)),
        expense(id: '3', date: DateTime(2026, 2, 1)),
      ];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        sort: ExpenseSortOption.newestFirst,
      );
      expect(result.map((e) => e.id).toList(), ['2', '3', '1']);
    });

    test('sorts oldest first', () {
      final expenses = [
        expense(id: '1', date: DateTime(2026, 1, 1)),
        expense(id: '2', date: DateTime(2026, 3, 1)),
      ];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        sort: ExpenseSortOption.oldestFirst,
      );
      expect(result.first.id, '1');
    });

    test('sorts highest amount', () {
      final expenses = [
        expense(id: '1', amount: 50),
        expense(id: '2', amount: 500),
        expense(id: '3', amount: 200),
      ];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        sort: ExpenseSortOption.highestAmount,
      );
      expect(result.first.id, '2');
    });

    test('sorts lowest amount', () {
      final expenses = [
        expense(id: '1', amount: 50),
        expense(id: '2', amount: 500),
      ];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        sort: ExpenseSortOption.lowestAmount,
      );
      expect(result.first.id, '1');
    });

    test('sorts by category name', () {
      final expenses = [
        expense(id: '1', categoryId: 'shopping'),
        expense(id: '2', categoryId: 'food'),
      ];
      final result = useCase(
        expenses: expenses,
        categories: categories,
        sort: ExpenseSortOption.category,
      );
      expect(result.first.id, '2'); // food before shopping
    });
  });

  group('CalculateExpenseSummaryUseCase', () {
    const useCase = CalculateExpenseSummaryUseCase();

    test('returns empty for empty list', () {
      final summary = useCase(const []);
      expect(summary.totalExpenses, 0);
      expect(summary.totalAmount, 0);
    });

    test('computes correct summary', () {
      final summary = useCase([
        expense(id: '1', amount: 100),
        expense(id: '2', amount: 300),
        expense(id: '3', amount: 200),
      ]);
      expect(summary.totalExpenses, 3);
      expect(summary.totalAmount, 600);
      expect(summary.averageExpense, 200);
      expect(summary.highestExpense, 300);
      expect(summary.lowestExpense, 100);
    });
  });

  group('PageExpensesUseCase', () {
    const useCase = PageExpensesUseCase(pageSize: 2);

    test('returns first page and hasMore', () {
      final items = [1, 2, 3, 4, 5].map((i) => expense(id: '$i')).toList();
      final page = useCase(offset: 0, items: items);
      expect(page.items.length, 2);
      expect(page.offset, 2);
      expect(page.hasMore, isTrue);
    });

    test('returns hasMore false at end', () {
      final items = [expense(id: '1'), expense(id: '2')];
      final page = useCase(offset: 0, items: items);
      expect(page.items.length, 2);
      expect(page.hasMore, isFalse);
    });

    test('returns empty when offset beyond end', () {
      final items = [expense(id: '1')];
      final page = useCase(offset: 5, items: items);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('GroupExpensesUseCase', () {
    const useCase = GroupExpensesUseCase();

    test('groups today and earlier', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final old = today.subtract(const Duration(days: 100));
      final groups = useCase([
        expense(id: '1', date: today),
        expense(id: '2', date: old),
      ]);
      expect(groups.length, 2);
      expect(groups.first.type.label, 'Today');
      expect(groups.last.type.label, 'Earlier');
    });

    test('groups yesterday correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final groups = useCase([expense(id: '1', date: yesterday)]);
      expect(groups.length, 1);
      expect(groups.first.type.label, 'Yesterday');
    });

    test('empty input returns empty groups', () {
      final groups = useCase(const []);
      expect(groups, isEmpty);
    });
  });
}
