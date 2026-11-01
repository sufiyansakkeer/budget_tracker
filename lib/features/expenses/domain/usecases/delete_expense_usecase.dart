import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';

/// Deletes an expense by id.
class DeleteExpenseUseCase {
  final ExpenseRepository repository;

  DeleteExpenseUseCase({required this.repository});

  Future<ExpenseResult<void>> call(String id) async {
    if (id.isEmpty) {
      return const ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.invalidInput,
          message: 'Expense id cannot be empty',
        ),
      );
    }

    // The read is inside the try too: a failure must come back as a result,
    // or the screen waiting on it stays on "saving".
    try {
      final existing = await repository.getExpenseById(id);
      if (existing == null) {
        return const ExpenseError(
          ExpenseFailure(
            type: ExpenseErrorType.notFound,
            message: 'Expense not found',
          ),
        );
      }
      await repository.deleteExpense(id);
      return const ExpenseSuccess(null);
    } catch (e) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.databaseFailure,
          message: 'Failed to delete expense: ${e.toString()}',
        ),
      );
    }
  }
}
