import '../../../expenses/domain/entities/expense_category.dart';

/// Data access for category management.
///
/// Read access for pickers stays on `ExpenseRepository.getCategories()`; this
/// contract adds the writes and the usage count needed to manage them.
abstract class CategoryRepository {
  /// Every category, archived ones included.
  Future<List<ExpenseCategory>> getCategories();

  Future<ExpenseCategory?> getCategoryById(String id);

  Future<void> createCategory(ExpenseCategory category);

  Future<void> updateCategory(ExpenseCategory category);

  Future<void> deleteCategory(String id);

  /// Number of expenses that reference [categoryId].
  Future<int> countExpenses(String categoryId);
}
