import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/features/expenses/domain/usecases/create_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/update_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';

class FakeBudgetRepository implements BudgetRepository {
  String? activeId = 'budget-1';

  @override
  Future<BudgetEntity?> getActiveBudget() async => null;

  @override
  Future<String?> getActiveBudgetId() async => activeId;

  @override
  Future<void> setActiveBudgetId(String budgetId) async {
    activeId = budgetId;
  }

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => null;

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async => [];

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
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    return 0;
  }

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    return 1;
  }

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0.0;
}

class FakeExpenseRepository implements ExpenseRepository {
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
    var result = store.values.toList();

    // Filter by budget ID if provided
    if (budgetId != null && budgetId.isNotEmpty) {
      result = result.where((e) => e.budgetId == budgetId).toList();
    }

    return result;
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async =>
      store.values.where((e) => budgetIds.contains(e.budgetId)).toList();
}

class FakeCreateUseCase implements CreateExpenseUseCase {
  @override
  final ExpenseRepository repository;
  FakeCreateUseCase(this.repository);

  @override
  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) async {
    await repository.createExpense(expense);
    return ExpenseSuccess(expense);
  }
}

class FakeUpdateUseCase implements UpdateExpenseUseCase {
  @override
  final ExpenseRepository repository;
  FakeUpdateUseCase(this.repository);

  @override
  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) async {
    await repository.updateExpense(expense);
    return ExpenseSuccess(expense);
  }
}

class FakeDeleteUseCase implements DeleteExpenseUseCase {
  @override
  final ExpenseRepository repository;
  FakeDeleteUseCase(this.repository);

  @override
  Future<ExpenseResult<void>> call(String id) async {
    await repository.deleteExpense(id);
    return const ExpenseSuccess(null);
  }
}

class FakeGetByIdUseCase implements GetExpenseByIdUseCase {
  @override
  final ExpenseRepository repository;
  FakeGetByIdUseCase(this.repository);

  @override
  Future<ExpenseResult<ExpenseEntity>> call(String id) async {
    final expense = await repository.getExpenseById(id);
    if (expense == null) {
      return const ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.notFound,
          message: 'Expense not found',
        ),
      );
    }
    return ExpenseSuccess(expense);
  }
}

class FakeGetAllUseCase implements GetExpensesUseCase {
  @override
  final ExpenseRepository repository;
  FakeGetAllUseCase(this.repository);

  @override
  Future<ExpenseResult<List<ExpenseEntity>>> call({
    String? budgetId,
    int? month,
    int? year,
  }) async {
    final expenses = await repository.getExpenses(
      budgetId: budgetId,
      month: month,
      year: year,
    );
    return ExpenseSuccess(expenses);
  }
}

class FakeGetCategoriesUseCase implements GetCategoriesUseCase {
  @override
  final ExpenseRepository repository;
  FakeGetCategoriesUseCase(this.repository);

  @override
  Future<ExpenseResult<List<ExpenseCategory>>> call() async {
    final categories = await repository.getCategories();
    return ExpenseSuccess(categories);
  }
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

ExpenseBloc buildBloc(ExpenseRepository repository) {
  return ExpenseBloc(
    createExpenseUseCase: FakeCreateUseCase(repository),
    updateExpenseUseCase: FakeUpdateUseCase(repository),
    deleteExpenseUseCase: FakeDeleteUseCase(repository),
    getExpenseByIdUseCase: FakeGetByIdUseCase(repository),
    getExpensesUseCase: FakeGetAllUseCase(repository),
    getCategoriesUseCase: FakeGetCategoriesUseCase(repository),
    repository: repository,
    budgetRepository: FakeBudgetRepository(),
  );
}

void main() {
  late FakeExpenseRepository repository;

  setUp(() {
    repository = FakeExpenseRepository();
  });

  test('initial state is ExpenseState initial', () {
    final bloc = buildBloc(repository);
    expect(bloc.state.status, ExpenseBlocStatus.initial);
    expect(bloc.state.categories, isEmpty);
    bloc.close();
  });

  test('loads categories successfully', () async {
    final bloc = buildBloc(repository);
    bloc.add(const ExpenseLoadCategories());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.categories.length, defaultCategories.length);
    await bloc.close();
  });

  test('loads expense by id', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    final bloc = buildBloc(repository);
    bloc.add(const ExpenseLoadById('exp-1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.expense?.id, 'exp-1');
    expect(bloc.state.status, ExpenseBlocStatus.loaded);
    await bloc.close();
  });

  test('loads all expenses', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    await repository.createExpense(expenseEntity('exp-2'));
    final bloc = buildBloc(repository);
    bloc.add(const ExpenseLoadAll());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.expenses.length, 2);
    await bloc.close();
  });

  test('creates an expense and sets success state', () async {
    final bloc = buildBloc(repository);
    bloc.add(ExpenseCreate(expenseEntity('exp-1')));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, ExpenseBlocStatus.success);
    expect(bloc.state.message, 'Expense added successfully');
    expect(repository.store.containsKey('exp-1'), isTrue);
    await bloc.close();
  });

  test('updates an expense and sets success state', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    final bloc = buildBloc(repository);
    bloc.add(ExpenseUpdate(expenseEntity('exp-1')));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, ExpenseBlocStatus.success);
    expect(bloc.state.message, 'Expense updated successfully');
    await bloc.close();
  });

  test('deletes an expense and sets success state', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    final bloc = buildBloc(repository);
    bloc.add(const ExpenseDelete('exp-1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, ExpenseBlocStatus.success);
    expect(bloc.state.message, 'Expense deleted successfully');
    expect(repository.store.containsKey('exp-1'), isFalse);
    await bloc.close();
  });

  test('clear message resets to initial', () async {
    await repository.createExpense(expenseEntity('exp-1'));
    final bloc = buildBloc(repository);
    bloc.add(const ExpenseDelete('exp-1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, ExpenseBlocStatus.success);
    bloc.add(const ExpenseClearMessage());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, ExpenseBlocStatus.initial);
    expect(bloc.state.message, isNull);
    await bloc.close();
  });

  // ──────────────────────────────────────────────────────────────
  // Regression tests for missing/overspent expenses bug
  // NOTE: These tests verify that BudgetId is properly resolved during creation
  // The actual refresh/reload behavior is tested in expense_history_bloc_test.dart
  // ──────────────────────────────────────────────────────────────

  test(
    'expense creation properly assigns budgetId when not provided',
    () async {
      final expenseWithoutBudget = ExpenseEntity(
        id: 'exp-test',
        budgetId: '', // Empty budgetId
        amount: 100.0,
        categoryId: 'food',
        date: DateTime(2026, 8, 5),
        time: DateTime(2026, 8, 5, 12, 0),
        createdAt: DateTime(2026, 8, 5),
        updatedAt: DateTime(2026, 8, 5),
      );

      final bloc = buildBloc(repository);
      bloc.add(ExpenseCreate(expenseWithoutBudget));
      await Future<void>.delayed(Duration.zero);

      // Should resolve budgetId from active budget and create successfully
      expect(bloc.state.status, ExpenseBlocStatus.success);
      expect(bloc.state.message, 'Expense added successfully');
      expect(repository.store.containsKey('exp-test'), isTrue);

      // Verify the expense now has a valid budgetId
      final savedExpense = repository.store['exp-test'];
      expect(savedExpense?.budgetId, isNotEmpty);
      expect(savedExpense?.budgetId, 'budget-1');
      await bloc.close();
    },
  );

  test('expense creation fails gracefully if no budget is available', () async {
    final budgetRepo = FakeBudgetRepository();
    budgetRepo.activeId = null; // No active budget

    final expenseWithoutBudget = ExpenseEntity(
      id: 'exp-no-budget',
      budgetId: '',
      amount: 100.0,
      categoryId: 'food',
      date: DateTime(2026, 8, 5),
      time: DateTime(2026, 8, 5, 12, 0),
      createdAt: DateTime(2026, 8, 5),
      updatedAt: DateTime(2026, 8, 5),
    );

    final bloc = ExpenseBloc(
      createExpenseUseCase: FakeCreateUseCase(repository),
      updateExpenseUseCase: FakeUpdateUseCase(repository),
      deleteExpenseUseCase: FakeDeleteUseCase(repository),
      getExpenseByIdUseCase: FakeGetByIdUseCase(repository),
      getExpensesUseCase: FakeGetAllUseCase(repository),
      getCategoriesUseCase: FakeGetCategoriesUseCase(repository),
      repository: repository,
      budgetRepository: budgetRepo,
    );

    bloc.add(ExpenseCreate(expenseWithoutBudget));
    await Future<void>.delayed(Duration.zero);

    // Should fail with appropriate error message
    expect(bloc.state.status, ExpenseBlocStatus.error);
    expect(bloc.state.message, isNotEmpty);
    expect(repository.store.containsKey('exp-no-budget'), isFalse);
    await bloc.close();
  });
}
