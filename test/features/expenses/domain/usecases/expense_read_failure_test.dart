import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/update_expense_usecase.dart';

import '../../presentation/expense_test_fakes.dart';

/// A read that fails while editing or deleting comes back as a failure. It
/// used to escape the use case, so the screen stayed on "saving".
void main() {
  late MemoryExpenseRepository repository;
  final expense = ExpenseEntity(
    id: 'lunch',
    budgetId: 'personal',
    amount: 120,
    categoryId: 'food',
    date: DateTime(2026, 8, 5),
    time: DateTime(2026, 8, 5, 13),
    createdAt: DateTime(2026, 8, 5),
    updatedAt: DateTime(2026, 8, 5),
  );

  setUp(() {
    repository = MemoryExpenseRepository()
      ..store[expense.id] = expense
      ..failReadById = 'database is locked';
  });

  test('update', () async {
    final result = await UpdateExpenseUseCase(repository: repository)(expense);

    expect(result, isA<ExpenseError>());
    expect(
      (result as ExpenseError).failure.type,
      ExpenseErrorType.databaseFailure,
    );
  });

  test('delete', () async {
    final result = await DeleteExpenseUseCase(repository: repository)('lunch');

    expect(result, isA<ExpenseError>());
    expect(
      (result as ExpenseError).failure.type,
      ExpenseErrorType.databaseFailure,
    );
  });
}
