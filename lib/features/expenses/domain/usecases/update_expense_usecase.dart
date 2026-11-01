import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';
import '../validators/expense_validator.dart';

/// Updates an existing expense, checked against the same rules as a new one.
class UpdateExpenseUseCase {
  final ExpenseRepository repository;

  UpdateExpenseUseCase({required this.repository});

  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) async {
    final invalid = ExpenseValidator.check(expense);
    if (invalid != null) return ExpenseError(invalid);

    // The read is inside the try too: a failure must come back as a result,
    // or the screen waiting on it stays on "saving".
    try {
      final existing = await repository.getExpenseById(expense.id);
      if (existing == null) {
        return const ExpenseError(
          ExpenseFailure(
            type: ExpenseErrorType.notFound,
            message: 'Expense not found',
          ),
        );
      }
      await repository.updateExpense(expense);
      return ExpenseSuccess(expense);
    } catch (e) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.databaseFailure,
          message: 'Failed to update expense: ${e.toString()}',
        ),
      );
    }
  }
}
