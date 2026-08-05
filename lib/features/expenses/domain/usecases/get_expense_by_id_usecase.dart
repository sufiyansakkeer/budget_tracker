import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';

/// Loads a single expense by id.
class GetExpenseByIdUseCase {
  final ExpenseRepository repository;

  GetExpenseByIdUseCase({required this.repository});

  Future<ExpenseResult<ExpenseEntity>> call(String id) async {
    try {
      final expense = await repository.getExpenseById(id);
      if (expense == null) {
        return const ExpenseError(
          ExpenseFailure(
            type: ExpenseErrorType.notFound,
            message: 'Expense not found',
          ),
        );
      }
      return ExpenseSuccess(expense);
    } catch (e) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.databaseFailure,
          message: 'Failed to load expense: ${e.toString()}',
        ),
      );
    }
  }
}
