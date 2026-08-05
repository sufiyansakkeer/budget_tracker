import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';
import '../validators/expense_validator.dart';

/// Creates a new expense after validating its input.
class CreateExpenseUseCase {
  final ExpenseRepository repository;

  CreateExpenseUseCase({required this.repository});

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

    final dateError = ExpenseValidator.validateDate(expense.date);
    if (dateError != null) {
      return ExpenseError(
        ExpenseFailure(type: ExpenseErrorType.invalidInput, message: dateError),
      );
    }

    final noteError = ExpenseValidator.validateNote(expense.note);
    if (noteError != null) {
      return ExpenseError(
        ExpenseFailure(type: ExpenseErrorType.invalidInput, message: noteError),
      );
    }

    final receiptError = ExpenseValidator.validateReceiptPath(
      expense.receiptImagePath,
    );
    if (receiptError != null) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.missingReceipt,
          message: receiptError,
        ),
      );
    }

    try {
      await repository.createExpense(expense);
      return ExpenseSuccess(expense);
    } catch (e) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.databaseFailure,
          message: 'Failed to save expense: ${e.toString()}',
        ),
      );
    }
  }
}
