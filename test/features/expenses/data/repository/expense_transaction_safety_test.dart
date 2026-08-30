import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';

/// A fake data source that tracks transaction calls.
class TrackingExpenseDataSource implements ExpenseLocalDataSource {
  final Map<String, ExpenseEntity> store = {};
  int transactionCount = 0;
  bool throwInTransaction = false;

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
  }) async =>
      store.values.toList();

  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;

  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async =>
      store.values.where((e) => budgetIds.contains(e.budgetId)).toList();

  @override
  Future<void> seedDefaultCategories(List<ExpenseCategory> categories) async {}

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    transactionCount++;
    if (throwInTransaction) {
      throw Exception('Transaction failed');
    }
    return action();
  }
}

/// A fake budget repository that tracks update calls.
class TrackingBudgetRepository implements BudgetRepository {
  final List<String> updatedBudgetIds = [];
  bool throwOnUpdate = false;

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {
    if (throwOnUpdate) {
      throw Exception('Budget update failed');
    }
    updatedBudgetIds.add(budgetId);
  }

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
  }) async =>
      throw UnimplementedError();
  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async =>
      throw UnimplementedError();
  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async =>
      MonthlyStatisticsEntity.empty;
  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async =>
      0;
  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async =>
      30;
  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async =>
      const BudgetError(
        BudgetFailure(type: BudgetErrorType.notFound, message: 'Not found'),
      );
  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async =>
      0.0;
}

ExpenseEntity makeExpense(String id, {String budgetId = 'budget-1'}) {
  final now = DateTime(2026, 8, 15);
  return ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: 100,
    categoryId: 'food',
    date: now,
    time: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late TrackingExpenseDataSource dataSource;
  late TrackingBudgetRepository budgetRepository;
  late ExpenseRepositoryImpl repository;

  setUp(() {
    dataSource = TrackingExpenseDataSource();
    budgetRepository = TrackingBudgetRepository();
    repository = ExpenseRepositoryImpl(
      localDataSource: dataSource,
      budgetRepository: budgetRepository,
    );
  });

  group('Transaction safety', () {
    test('createExpense calls transaction', () async {
      await repository.createExpense(makeExpense('exp-1'));
      expect(dataSource.transactionCount, 1);
      expect(dataSource.store.containsKey('exp-1'), isTrue);
      expect(budgetRepository.updatedBudgetIds, contains('budget-1'));
    });

    test('updateExpense calls transaction', () async {
      dataSource.store['exp-1'] = makeExpense('exp-1');
      await repository.updateExpense(makeExpense('exp-1'));
      expect(dataSource.transactionCount, 1);
      expect(budgetRepository.updatedBudgetIds, contains('budget-1'));
    });

    test('deleteExpense calls transaction', () async {
      dataSource.store['exp-1'] = makeExpense('exp-1');
      await repository.deleteExpense('exp-1');
      expect(dataSource.transactionCount, 1);
      expect(dataSource.store.containsKey('exp-1'), isFalse);
      expect(budgetRepository.updatedBudgetIds, contains('budget-1'));
    });

    test('deleteExpense skips non-existent expense', () async {
      await repository.deleteExpense('nonexistent');
      expect(dataSource.transactionCount, 0);
      expect(budgetRepository.updatedBudgetIds, isEmpty);
    });

    test('createExpense rolls back if budget update fails', () async {
      budgetRepository.throwOnUpdate = true;

      try {
        await repository.createExpense(makeExpense('exp-fail'));
      } catch (_) {
        // Expected
      }

      // Transaction was called but budget update threw.
      expect(dataSource.transactionCount, 1);
    });

    test('each operation uses exactly one transaction', () async {
      await repository.createExpense(makeExpense('exp-1'));
      expect(dataSource.transactionCount, 1);

      dataSource.store['exp-2'] = makeExpense('exp-2');
      await repository.updateExpense(makeExpense('exp-2'));
      expect(dataSource.transactionCount, 2);

      await repository.deleteExpense('exp-1');
      expect(dataSource.transactionCount, 3);
    });
  });
}
