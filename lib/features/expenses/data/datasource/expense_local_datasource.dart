import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';

/// Local data access for expense CRUD operations.
abstract class ExpenseLocalDataSource {
  Future<void> createExpense(ExpenseEntity expense);

  Future<void> updateExpense(ExpenseEntity expense);

  Future<void> deleteExpense(String id);

  Future<ExpenseEntity?> getExpenseById(String id);

  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
  });

  /// Returns expenses belonging to any of the given [budgetIds].
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  });

  Future<List<ExpenseCategory>> getCategories();

  Future<void> seedDefaultCategories(List<ExpenseCategory> categories);
}
