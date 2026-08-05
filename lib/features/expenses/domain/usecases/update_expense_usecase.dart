import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';
import '../validators/expense_validator.dart';

/// Updates an existing expense after validating its input.
class UpdateExpenseUseCase {
  final ExpenseRepository repository;

  UpdateExpenseUseCase({required this.repository});

  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) async {
    final amountError = ExpenseValidator.validateAmountValue(expense.amount);
    if (amountError != null) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.invalidInput,
          message: amountError,
        ),
      );
    }

    final categoryError = ExpenseValidator.validateCategory(expense.categoryId);
    if (categoryError != null) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.invalidInput,
          message: categoryError,
        ),
      );
    }

    final existing = await repository.getExpenseById(expense.id);
    if (existing == null) {
      return const ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.notFound,
          message: 'Expense not found',
        ),
      );
    }

    try {
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
