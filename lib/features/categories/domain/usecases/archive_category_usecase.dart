import '../../../expenses/domain/entities/expense_category.dart';
import '../entities/category_failure.dart';
import '../repository/category_repository.dart';

/// Hides a category from pickers (or restores it). Expenses keep it.
///
/// At least one category must stay available, otherwise the expense form
/// would have nothing to offer.
class ArchiveCategoryUseCase {
  final CategoryRepository repository;

  const ArchiveCategoryUseCase({required this.repository});

  Future<CategoryResult<ExpenseCategory>> call(
    String id, {
    required bool archived,
  }) async {
    try {
      final current = await repository.getCategoryById(id);
      if (current == null) {
        return const CategoryError(
          CategoryFailure(
            type: CategoryErrorType.notFound,
            message: 'Category not found',
          ),
        );
      }
      if (archived) {
        final all = await repository.getCategories();
        final activeOthers = all.where((c) => !c.isArchived && c.id != id);
        if (activeOthers.isEmpty) {
          return const CategoryError(
            CategoryFailure(
              type: CategoryErrorType.lastActive,
              message: 'Keep at least one category available',
            ),
          );
        }
      }
      final updated = current.copyWith(isArchived: archived);
      await repository.updateCategory(updated);
      return CategorySuccess(updated);
    } catch (e) {
      return CategoryError(
        CategoryFailure(
          type: CategoryErrorType.databaseFailure,
          message: 'Failed to update category: $e',
        ),
      );
    }
  }
}
