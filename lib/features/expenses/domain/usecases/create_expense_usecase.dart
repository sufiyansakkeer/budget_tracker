import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';
import '../validators/expense_validator.dart';

/// Creates a new expense after validating its input.
class CreateExpenseUseCase {
  final ExpenseRepository repository;

  CreateExpenseUseCase({required this.repository});

  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) async {
    final invalid = ExpenseValidator.check(expense);
    if (invalid != null) return ExpenseError(invalid);

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
