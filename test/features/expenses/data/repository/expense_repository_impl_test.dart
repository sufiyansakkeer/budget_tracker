import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/features/expenses/data/datasource/expense_local_datasource.dart';
import 'package:budget_tracker/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_category.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_entity.dart';

class FakeExpenseLocalDataSource implements ExpenseLocalDataSource {
  final Map<String, ExpenseEntity> store = {};

  @override
  Future<void> createExpense(ExpenseEntity expense) async {
    store[expense.id] = expense;
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    store[expense.id] = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    store.remove(id);
  }

  @override
  Future<ExpenseEntity?> getExpenseById(String id) async => store[id];

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
  }) async {
    return store.values.toList();
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;

  @override
  Future<void> seedDefaultCategories(List<ExpenseCategory> categories) async {}
}

ExpenseEntity expenseEntity(String id) {
  final now = DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    budgetId: 'budget-1',
    amount: 100.0,
    categoryId: 'food',
    date: now,
    time: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeExpenseLocalDataSource dataSource;
  late ExpenseRepositoryImpl repository;

  setUp(() {
    dataSource = FakeExpenseLocalDataSource();
    repository = ExpenseRepositoryImpl(localDataSource: dataSource);
  });

  test('createExpense delegates to data source and stores record', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    expect(dataSource.store.containsKey('exp-1'), isTrue);
  });

  test('updateExpense updates stored record', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    final updated = expenseEntity('exp-1');
    await repository.updateExpense(updated);
    expect(dataSource.store['exp-1']!.amount, 100.0);
  });

  test('deleteExpense removes record', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    await repository.deleteExpense('exp-1');
    expect(dataSource.store.containsKey('exp-1'), isFalse);
  });

  test('getExpenseById returns stored expense', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    final result = await repository.getExpenseById('exp-1');
    expect(result?.id, 'exp-1');
  });

  test('getExpenseById returns null for missing id', () async {
    final result = await repository.getExpenseById('missing');
    expect(result, isNull);
  });

  test('getExpenses returns all stored expenses', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    await repository.createExpense(expenseEntity('exp-2'));
    final result = await repository.getExpenses();
    expect(result.length, 2);
  });

  test('getCategories returns seeded default categories', () async {
    final result = await repository.getCategories();
    expect(result.length, defaultCategories.length);
  });
}
