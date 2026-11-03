import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/usecases/update_expense_usecase.dart';

import '../../presentation/expense_test_fakes.dart';

/// An edit is checked against the same rules as a new expense. Editing used
/// to check only the amount and category, so a future date or an over-long
/// note saved on edit although adding refused them.
void main() {
  late MemoryExpenseRepository repository;
  final today = DateTime.now();
  final saved = ExpenseEntity(
    id: 'lunch',
    budgetId: 'personal',
    amount: 120,
    categoryId: 'food',
    date: DateTime(today.year, today.month, today.day),
    time: DateTime(today.year, today.month, today.day, 9),
    createdAt: DateTime(today.year, today.month, today.day),
    updatedAt: DateTime(today.year, today.month, today.day),
  );

  setUp(() => repository = MemoryExpenseRepository()..store['lunch'] = saved);

  Future<ExpenseErrorType?> editTo(ExpenseEntity edited) async {
    final result = await UpdateExpenseUseCase(repository: repository)(edited);
    return switch (result) {
      ExpenseError(:final failure) => failure.type,
      ExpenseSuccess() => null,
    };
  }

  test('a future date is refused', () async {
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    expect(
      await editTo(saved.copyWith(date: tomorrow)),
      ExpenseErrorType.invalidInput,
    );
    expect(repository.store['lunch']!.date, saved.date);
  });

  test('a note past the limit is refused', () async {
    expect(
      await editTo(saved.copyWith(note: 'x' * 501)),
      ExpenseErrorType.invalidInput,
    );
  });

  test('a valid edit still saves', () async {
    expect(await editTo(saved.copyWith(amount: 150)), isNull);
    expect(repository.store['lunch']!.amount, 150);
  });
}
