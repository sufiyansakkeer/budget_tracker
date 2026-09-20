import 'package:flutter/material.dart';

import '../../../../../core/widgets/empty_state.dart';

/// Contextual empty states for the history screen.
///
/// Handles three cases:
/// * No expenses at all (encourages adding the first expense)
/// * No search results
/// * No filtered results
class ExpenseHistoryEmptyState extends StatelessWidget {
  /// Whether there are any expenses at all in the current scope.
  final bool hasAnyExpenses;

  /// Whether there is an active search query.
  final bool hasSearchQuery;

  /// Whether there is an active filter set.
  final bool hasActiveFilters;

  final VoidCallback? onAddFirst;
  final VoidCallback? onClearFilters;

  const ExpenseHistoryEmptyState({
    super.key,
    required this.hasAnyExpenses,
    required this.hasSearchQuery,
    required this.hasActiveFilters,
    this.onAddFirst,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasAnyExpenses) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No expenses yet',
        message:
            'Record what you spend and it will show up here, grouped '
            'by day.',
        actionLabel: 'Add Your First Expense',
        actionIcon: Icons.add_rounded,
        onAction: onAddFirst,
      );
    }
    if (hasSearchQuery && !hasActiveFilters) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No search results',
        message:
            'Nothing matches that search. Try a different word, or '
            'search by category or tag.',
        actionLabel: 'Clear Search',
        actionIcon: Icons.clear_all_rounded,
        onAction: onClearFilters,
      );
    }
    if (hasSearchQuery || hasActiveFilters) {
      return EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'No filtered results',
        message: 'No expenses match the current filters.',
        actionLabel: 'Clear Filters',
        actionIcon: Icons.clear_all_rounded,
        onAction: onClearFilters,
      );
    }
    return const EmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'Nothing to show',
      message: 'Your expenses will appear here.',
    );
  }
}
