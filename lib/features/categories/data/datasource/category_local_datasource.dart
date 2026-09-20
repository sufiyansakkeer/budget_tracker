import '../../../expenses/domain/entities/expense_category.dart';

abstract class CategoryLocalDataSource {
  Future<List<ExpenseCategory>> getCategories();
  Future<ExpenseCategory?> getCategoryById(String id);
  Future<void> createCategory(ExpenseCategory category);
  Future<void> updateCategory(ExpenseCategory category);
  Future<void> deleteCategory(String id);
  Future<int> countExpenses(String categoryId);
}
