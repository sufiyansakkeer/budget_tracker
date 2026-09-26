import '../entities/category_failure.dart';
import '../repository/category_repository.dart';

/// Permanently removes a custom category that no expense references.
///
/// System categories and categories in use cannot be deleted — archive them
/// instead, so history keeps its labels and the database foreign key holds.
class DeleteCategoryUseCase {
  final CategoryRepository repository;

  const DeleteCategoryUseCase({required this.repository});

  Future<CategoryResult<void>> call(String id) async {
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
      if (current.isSystem) {
        return const CategoryError(
          CategoryFailure(
            type: CategoryErrorType.systemCategory,
            message: 'Built-in categories can be archived but not deleted',
          ),
        );
      }
      final count = await repository.countExpenses(id);
      if (count > 0) {
        return CategoryError(
          CategoryFailure(
            type: CategoryErrorType.inUse,
            message:
                '"${current.name}" is used by $count '
                '${count == 1 ? 'expense' : 'expenses'}. Archive it instead.',
          ),
        );
      }
      await repository.deleteCategory(id);
      return const CategorySuccess(null);
    } catch (e) {
      return CategoryError(
        CategoryFailure(
          type: CategoryErrorType.databaseFailure,
          message: 'Failed to delete category: $e',
        ),
      );
    }
  }
}
