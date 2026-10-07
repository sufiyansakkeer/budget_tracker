import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';

/// Local data access for expense CRUD operations.
abstract class ExpenseLocalDataSource {
  Future<void> createExpense(ExpenseEntity expense);

  /// Writes the editable fields of [expense]. `bill_id` is never taken from
  /// the entity (edit forms build a fresh one); [clearBillId] is the only way
  /// to change it, used when the expense moves to another budget.
  Future<void> updateExpense(ExpenseEntity expense, {bool clearBillId = false});

  Future<void> deleteExpense(String id);

  Future<ExpenseEntity?> getExpenseById(String id);

  /// Expenses for [budgetId], newest first.
  ///
  /// [from]/[to] bound the date inclusively and are served by the
  /// `(budget_id, date)` index; [month]/[year] are the older month-scoped
  /// form and are ignored when a range is given.
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

  /// Expenses whose `bill_id` is [billId], newest first.
  Future<List<ExpenseEntity>> getExpensesForBill(String billId);

  Future<List<ExpenseCategory>> getCategories();

  Future<void> seedDefaultCategories(List<ExpenseCategory> categories);

  /// Runs [action] inside a database transaction. If [action] throws, all
  /// changes within are rolled back.
  Future<T> transaction<T>(Future<T> Function() action);
}
