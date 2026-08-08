import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';

/// Loads all expenses, optionally filtered by budget, month and year.
class GetExpensesUseCase {
  final ExpenseRepository repository;

  GetExpensesUseCase({required this.repository});

  Future<ExpenseResult<List<ExpenseEntity>>> call({
    String? budgetId,
    int? month,
    int? year,
  }) async {
    try {
      final expenses = await repository.getExpenses(
        budgetId: budgetId,
        month: month,
        year: year,
      );
      return ExpenseSuccess(expenses);
    } catch (e) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.databaseFailure,
          message: 'Failed to load expenses: ${e.toString()}',
        ),
      );
    }
  }
}
