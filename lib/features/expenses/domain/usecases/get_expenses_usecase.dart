import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';

/// Loads expenses, optionally scoped to a budget, a month or a date range.
class GetExpensesUseCase {
  final ExpenseRepository repository;

  GetExpensesUseCase({required this.repository});

  Future<ExpenseResult<List<ExpenseEntity>>> call({
    String? budgetId,
    int? month,
    int? year,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final expenses = await repository.getExpenses(
        budgetId: budgetId,
        month: month,
        year: year,
        from: from,
        to: to,
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
