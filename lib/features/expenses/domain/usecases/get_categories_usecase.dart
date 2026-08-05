import '../entities/expense_category.dart';
import '../entities/expense_failure.dart';
import '../repository/expense_repository.dart';

/// Loads all expense categories.
class GetCategoriesUseCase {
  final ExpenseRepository repository;

  GetCategoriesUseCase({required this.repository});

  Future<ExpenseResult<List<ExpenseCategory>>> call() async {
    try {
      final categories = await repository.getCategories();
      return ExpenseSuccess(categories);
    } catch (e) {
      return ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.databaseFailure,
          message: 'Failed to load categories: ${e.toString()}',
        ),
      );
    }
  }
}
