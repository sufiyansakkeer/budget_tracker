import 'package:uuid/uuid.dart';

import '../../../expenses/domain/entities/expense_category.dart';
import '../entities/category_failure.dart';
import '../repository/category_repository.dart';
import '../validators/category_validator.dart';

/// Creates a category (when [id] is null) or updates an existing one.
///
/// Rules: name 1–40 chars and unique (case-insensitive), icon from the
/// catalog, colour `#RRGGBB`. System categories can be renamed and restyled
/// but never lose their `isSystem` flag.
class SaveCategoryUseCase {
  final CategoryRepository repository;
  final String Function() _newId;

  SaveCategoryUseCase({
    required this.repository,
    String Function()? idGenerator,
  }) : _newId = idGenerator ?? (() => const Uuid().v4());

  Future<CategoryResult<ExpenseCategory>> call({
    String? id,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final error =
        CategoryValidator.validateName(name) ??
        CategoryValidator.validateIcon(icon) ??
        CategoryValidator.validateColor(colorHex);
    if (error != null) {
      return CategoryError(
        CategoryFailure(type: CategoryErrorType.invalidInput, message: error),
      );
    }
    final trimmedName = name.trim();
    final normalizedColor = colorHex.trim().toUpperCase();

    try {
      final existing = await repository.getCategories();
      final clash = existing.any(
        (c) => c.id != id && CategoryValidator.sameName(c.name, trimmedName),
      );
      if (clash) {
        return const CategoryError(
          CategoryFailure(
            type: CategoryErrorType.duplicateName,
            message: 'A category with this name already exists',
          ),
        );
      }

      if (id == null) {
        final category = ExpenseCategory(
          id: _newId(),
          name: trimmedName,
          icon: icon,
          colorHex: normalizedColor,
          isSystem: false,
        );
        await repository.createCategory(category);
        return CategorySuccess(category);
      }

      final current = await repository.getCategoryById(id);
      if (current == null) {
        return const CategoryError(
          CategoryFailure(
            type: CategoryErrorType.notFound,
            message: 'Category not found',
          ),
        );
      }
      final updated = current.copyWith(
        name: trimmedName,
        icon: icon,
        colorHex: normalizedColor,
      );
      await repository.updateCategory(updated);
      return CategorySuccess(updated);
    } catch (e) {
      return CategoryError(
        CategoryFailure(
          type: CategoryErrorType.databaseFailure,
          message: 'Failed to save category: $e',
        ),
      );
    }
  }
}
