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

    final existing = await repository.getExpenseById(id);
    if (existing == null) {
      return const ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.notFound,
          message: 'Expense not found',
        ),
      );
    }

    try {
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
