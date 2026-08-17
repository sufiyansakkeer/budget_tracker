import 'package:flutter_test/flutter_test.dart';
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

class FakeExpenseRepository implements ExpenseRepository {
  final Map<String, ExpenseEntity> store = {};
  bool throwOnWrite = false;

  @override
  Future<void> createExpense(ExpenseEntity expense) async {
    if (throwOnWrite) throw Exception('db failure');
    store[expense.id] = expense;
  }

  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    if (throwOnWrite) throw Exception('db failure');
    store[expense.id] = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    if (throwOnWrite) throw Exception('db failure');
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
    if (throwOnWrite) throw Exception('db failure');
    return store.values.toList();
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
}

ExpenseEntity validExpense({
  String id = 'exp-1',
  String budgetId = 'budget-1',
  double amount = 50.0,
  String categoryId = 'food',
}) {
  final now = DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: amount,
    categoryId: categoryId,
    date: now,
    time: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeExpenseRepository repository;

  setUp(() {
    repository = FakeExpenseRepository();
  });

  group('CreateExpenseUseCase', () {
    test('creates expense successfully with valid input', () async {
      final useCase = CreateExpenseUseCase(repository: repository);
      final expense = validExpense();

      final result = await useCase(expense);

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(repository.store.values.length, 1);
    });

    test('returns invalidInput error for zero amount', () async {
      final useCase = CreateExpenseUseCase(repository: repository);
      final expense = validExpense(amount: 0);

      final result = await useCase(expense);

      expect(result, isA<ExpenseError<ExpenseEntity>>());
      final error = result as ExpenseError<ExpenseEntity>;
      expect(error.failure.type, ExpenseErrorType.invalidInput);
    });

    test('returns invalidInput error for missing category', () async {
      final useCase = CreateExpenseUseCase(repository: repository);
      final expense = validExpense(categoryId: '');

      final result = await useCase(expense);

      expect(result, isA<ExpenseError<ExpenseEntity>>());
      final error = result as ExpenseError<ExpenseEntity>;
      expect(error.failure.type, ExpenseErrorType.invalidInput);
    });

    test('returns databaseFailure when repository throws', () async {
      repository.throwOnWrite = true;
      final useCase = CreateExpenseUseCase(repository: repository);
      final expense = validExpense();

      final result = await useCase(expense);

      expect(result, isA<ExpenseError<ExpenseEntity>>());
      final error = result as ExpenseError<ExpenseEntity>;
      expect(error.failure.type, ExpenseErrorType.databaseFailure);
    });
  });

  group('UpdateExpenseUseCase', () {
    test('updates an existing expense successfully', () async {
      repository.store['exp-1'] = validExpense();
      final useCase = UpdateExpenseUseCase(repository: repository);
      final updated = validExpense(amount: 99.0);

      final result = await useCase(updated);

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect(repository.store['exp-1']!.amount, 99.0);
    });

    test('returns notFound when expense does not exist', () async {
      final useCase = UpdateExpenseUseCase(repository: repository);
      final expense = validExpense();

      final result = await useCase(expense);

      expect(result, isA<ExpenseError<ExpenseEntity>>());
      final error = result as ExpenseError<ExpenseEntity>;
      expect(error.failure.type, ExpenseErrorType.notFound);
    });

    test('returns databaseFailure when repository throws', () async {
      repository.store['exp-1'] = validExpense();
      repository.throwOnWrite = true;
      final useCase = UpdateExpenseUseCase(repository: repository);

      final result = await useCase(validExpense());

      expect(result, isA<ExpenseError<ExpenseEntity>>());
      final error = result as ExpenseError<ExpenseEntity>;
      expect(error.failure.type, ExpenseErrorType.databaseFailure);
    });
  });

  group('DeleteExpenseUseCase', () {
    test('deletes an existing expense successfully', () async {
      repository.store['exp-1'] = validExpense();
      final useCase = DeleteExpenseUseCase(repository: repository);

      final result = await useCase('exp-1');

      expect(result, isA<ExpenseSuccess<void>>());
      expect(repository.store.containsKey('exp-1'), isFalse);
    });

    test('returns invalidInput for empty id', () async {
      final useCase = DeleteExpenseUseCase(repository: repository);

      final result = await useCase('');

      expect(result, isA<ExpenseError<void>>());
      final error = result as ExpenseError<void>;
      expect(error.failure.type, ExpenseErrorType.invalidInput);
    });

    test('returns notFound when expense does not exist', () async {
      final useCase = DeleteExpenseUseCase(repository: repository);

      final result = await useCase('missing');

      expect(result, isA<ExpenseError<void>>());
      final error = result as ExpenseError<void>;
      expect(error.failure.type, ExpenseErrorType.notFound);
    });
  });

  group('GetExpenseByIdUseCase', () {
    test('returns expense when found', () async {
      repository.store['exp-1'] = validExpense();
      final useCase = GetExpenseByIdUseCase(repository: repository);

      final result = await useCase('exp-1');

      expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
      expect((result as ExpenseSuccess<ExpenseEntity>).data.id, 'exp-1');
    });

    test('returns notFound when missing', () async {
      final useCase = GetExpenseByIdUseCase(repository: repository);

      final result = await useCase('missing');

      expect(result, isA<ExpenseError<ExpenseEntity>>());
      expect(
        (result as ExpenseError<ExpenseEntity>).failure.type,
        ExpenseErrorType.notFound,
      );
    });
  });

  group('GetCategoriesUseCase', () {
    test('returns categories successfully', () async {
      final useCase = GetCategoriesUseCase(repository: repository);

      final result = await useCase();

      expect(result, isA<ExpenseSuccess<List<ExpenseCategory>>>());
      expect(
        (result as ExpenseSuccess<List<ExpenseCategory>>).data.length,
        defaultCategories.length,
      );
    });
  });

  group('GetExpensesUseCase', () {
    test('returns all expenses', () async {
      repository.store['exp-1'] = validExpense(id: 'exp-1');
      repository.store['exp-2'] = validExpense(id: 'exp-2');
      final useCase = GetExpensesUseCase(repository: repository);

      final result = await useCase();

      expect(result, isA<ExpenseSuccess<List<ExpenseEntity>>>());
      expect((result as ExpenseSuccess<List<ExpenseEntity>>).data.length, 2);
    });

    test('returns databaseFailure when repository throws', () async {
      repository.throwOnWrite = true;
      final useCase = GetExpensesUseCase(repository: repository);

      final result = await useCase();

      expect(result, isA<ExpenseError<List<ExpenseEntity>>>());
    });
  });
}
