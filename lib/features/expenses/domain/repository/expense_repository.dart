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

  /// Returns expenses, optionally scoped to a budget and a date range.
  ///
  /// A [from]/[to] range is applied in SQL rather than in Dart, so a report
  /// or a summary never loads a budget's whole history to look at one week.
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
    DateTime? from,
    DateTime? to,
  });

  /// Returns expenses belonging to any of the given [budgetIds].
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  });

  /// Returns all available categories.
  Future<List<ExpenseCategory>> getCategories();
}
