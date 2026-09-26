import '../../../expenses/domain/entities/expense_category.dart';
import '../../domain/repository/category_repository.dart';
import '../datasource/category_local_datasource.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDataSource localDataSource;

  CategoryRepositoryImpl({required this.localDataSource});

  @override
  Future<List<ExpenseCategory>> getCategories() =>
      localDataSource.getCategories();

  @override
  Future<ExpenseCategory?> getCategoryById(String id) =>
      localDataSource.getCategoryById(id);

  @override
  Future<void> createCategory(ExpenseCategory category) =>
      localDataSource.createCategory(category);

  @override
  Future<void> updateCategory(ExpenseCategory category) =>
      localDataSource.updateCategory(category);

  @override
  Future<void> deleteCategory(String id) => localDataSource.deleteCategory(id);

  @override
  Future<int> countExpenses(String categoryId) =>
      localDataSource.countExpenses(categoryId);
}
