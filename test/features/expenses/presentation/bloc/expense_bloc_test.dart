import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_category.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_entity.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_failure.dart';
import 'package:budget_tracker/features/expenses/domain/repository/expense_repository.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/create_expense_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/update_expense_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:budget_tracker/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:budget_tracker/features/expenses/presentation/bloc/expense_event.dart';
import 'package:budget_tracker/features/expenses/presentation/bloc/expense_state.dart';

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
  Future<List<ExpenseEntity>> getExpenses({int? month, int? year}) async {
    return store.values.toList();
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
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
    int? month,
    int? year,
  }) async {
    final expenses = await repository.getExpenses(month: month, year: year);
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
}
