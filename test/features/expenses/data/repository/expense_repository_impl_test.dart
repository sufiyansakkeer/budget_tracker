import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

class MockBudgetRepository implements BudgetRepository {
  @override
  Future<BudgetEntity?> getActiveBudget() async => null;

  @override
  Future<String?> getActiveBudgetId() async => null;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {}

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => null;

  @override
  Future<List<BudgetEntity>> getAllBudgets({options}) async => [];

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) async => budget;

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async => budget;

  @override
  Future<void> deleteBudget(String id) async {}

  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async => BudgetEntity(
    id: id,
    name: 'Test',
    monthlyAmount: 1000,
    remainingAmount: 1000,
    currency: 'INR',
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => BudgetEntity(
    id: id,
    name: newName,
    monthlyAmount: 1000,
    remainingAmount: 1000,
    currency: 'INR',
    startDate: startDate ?? DateTime.now(),
    endDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => MonthlyStatisticsEntity.empty;

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 0;

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 30;

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async => const BudgetError(
    BudgetFailure(type: BudgetErrorType.notFound, message: 'Not found'),
  );

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0.0;
}

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
  late MockBudgetRepository budgetRepository;
  late ExpenseRepositoryImpl repository;

  setUp(() {
    dataSource = FakeExpenseLocalDataSource();
    budgetRepository = MockBudgetRepository();
    repository = ExpenseRepositoryImpl(
      localDataSource: dataSource,
      budgetRepository: budgetRepository,
    );
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
