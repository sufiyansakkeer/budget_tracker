import '../../../expenses/domain/entities/expense_category.dart';
import '../entities/category_failure.dart';
import '../repository/category_repository.dart';

/// Loads every category (active first, then archived), sorted by name within
/// each group with system categories keeping their seeded order.
class LoadCategoriesUseCase {
  final CategoryRepository repository;

  const LoadCategoriesUseCase({required this.repository});

  Future<CategoryResult<List<ExpenseCategory>>> call() async {
    try {
      final all = await repository.getCategories();
      final sorted = [...all]
        ..sort((a, b) {
          if (a.isArchived != b.isArchived) return a.isArchived ? 1 : -1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return CategorySuccess(sorted);
    } catch (e) {
      return CategoryError(
        CategoryFailure(
          type: CategoryErrorType.databaseFailure,
          message: 'Failed to load categories: $e',
        ),
      );
    }
  }
}
