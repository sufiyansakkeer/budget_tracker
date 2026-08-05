import '../entities/expense_category.dart';
import '../entities/expense_entity.dart';

/// Searches expenses by note, category name, and tags.
///
/// Matching is case-insensitive. Returns a new list containing only
/// expenses that match the query. An empty/blank query returns all expenses.
class SearchExpensesUseCase {
  const SearchExpensesUseCase();

  List<ExpenseEntity> call({
    required List<ExpenseEntity> expenses,
    required List<ExpenseCategory> categories,
    required String query,
  }) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return List.of(expenses);
    }

    final categoryNameById = <String, String>{
      for (final category in categories)
        category.id: category.name.toLowerCase(),
    };

    bool matches(ExpenseEntity expense) {
      final note = expense.note?.toLowerCase() ?? '';
      if (note.contains(trimmed)) return true;

      final categoryName = categoryNameById[expense.categoryId] ?? '';
      if (categoryName.contains(trimmed)) return true;

      for (final tag in expense.tags) {
        if (tag.toLowerCase().contains(trimmed)) return true;
      }
      return false;
    }

    return expenses.where(matches).toList();
  }
}
