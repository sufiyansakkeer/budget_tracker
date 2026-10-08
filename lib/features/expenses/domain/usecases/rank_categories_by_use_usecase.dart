import '../entities/expense_category.dart';
import '../entities/expense_entity.dart';

/// Orders categories by how often they were chosen, for the quick-add
/// shortcuts.
///
/// Read-only: it changes no expense and no figure. The most used category
/// comes first; a tie goes to the one used most recently, then to catalogue
/// order. Bill payments are left out, because their category follows the
/// bill rather than a choice. Archived categories are never offered. When
/// fewer than [limit] categories have been used, the rest are filled from
/// the catalogue, so a new install still gets a full row.
class RankCategoriesByUseUseCase {
  const RankCategoriesByUseUseCase();

  List<ExpenseCategory> call({
    required List<ExpenseCategory> categories,
    required List<ExpenseEntity> expenses,
    int limit = 5,
  }) {
    final available = [
      for (final c in categories)
        if (!c.isArchived) c,
    ];
    if (limit <= 0 || available.isEmpty) return const [];

    final catalogueIndex = {
      for (var i = 0; i < available.length; i++) available[i].id: i,
    };
    final counts = <String, int>{};
    final lastUsed = <String, DateTime>{};
    for (final e in expenses) {
      if (e.billId != null || !catalogueIndex.containsKey(e.categoryId)) {
        continue;
      }
      counts[e.categoryId] = (counts[e.categoryId] ?? 0) + 1;
      final previous = lastUsed[e.categoryId];
      if (previous == null || e.time.isAfter(previous)) {
        lastUsed[e.categoryId] = e.time;
      }
    }

    final used =
        [
          for (final c in available)
            if (counts.containsKey(c.id)) c,
        ]..sort((a, b) {
          final byCount = counts[b.id]!.compareTo(counts[a.id]!);
          if (byCount != 0) return byCount;
          final byRecent = lastUsed[b.id]!.compareTo(lastUsed[a.id]!);
          if (byRecent != 0) return byRecent;
          return catalogueIndex[a.id]!.compareTo(catalogueIndex[b.id]!);
        });

    return [
      ...used,
      for (final c in available)
        if (!counts.containsKey(c.id)) c,
    ].take(limit).toList();
  }
}
