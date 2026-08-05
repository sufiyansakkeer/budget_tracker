import '../entities/expense_category.dart';
import '../entities/expense_entity.dart';

/// Contract for expense data access consumed by use cases.
abstract class ExpenseRepository {
  /// Creates a new expense record.
  Future<void> createExpense(ExpenseEntity expense);

  /// Updates an existing expense record.
  Future<void> updateExpense(ExpenseEntity expense);

  /// Deletes an expense by id.
  Future<void> deleteExpense(String id);

  /// Returns an expense by id, or null if not found.
  Future<ExpenseEntity?> getExpenseById(String id);

  /// Returns all expenses, optionally filtered by month/year.
  Future<List<ExpenseEntity>> getExpenses({int? month, int? year});

  /// Returns all available categories.
  Future<List<ExpenseCategory>> getCategories();
}
