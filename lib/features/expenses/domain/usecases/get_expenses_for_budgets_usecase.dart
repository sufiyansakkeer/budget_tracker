import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';

/// Loads expenses belonging to any of the given [budgetIds].
class GetExpensesForBudgetsUseCase {
  final ExpenseRepository repository;

  GetExpensesForBudgetsUseCase({required this.repository});

  Future<ExpenseResult<List<ExpenseEntity>>> call({
    required List<String> budgetIds,
  }) async {
    try {
      final expenses = await repository.getExpensesForBudgets(
        budgetIds: budgetIds,
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
