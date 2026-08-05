import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';

/// Beautiful contextual empty states for the history screen.
///
/// Handles three cases:
/// * No expenses at all (encourages adding the first expense)
/// * No search results
/// * No filtered results
class ExpenseHistoryEmptyState extends StatelessWidget {
  /// Whether there are any expenses at all in the database.
  final bool hasAnyExpenses;

  /// Whether there is an active search query.
  final bool hasSearchQuery;

  /// Whether there is an active filter set.
  final bool hasActiveFilters;

  final VoidCallback? onAddFirst;
  final VoidCallback? onClearFilters;

  bool get _hasSearchOrFilter => hasSearchQuery || hasActiveFilters;

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
    final theme = Theme.of(context);

    final String title;
    final String subtitle;
    final IconData icon;
    final String? actionLabel;
    final VoidCallback? action;

    if (!hasAnyExpenses) {
      title = 'No expenses yet';
      subtitle = 'Add your first expense to get started';
      icon = Icons.receipt_long;
      actionLabel = 'Add Your First Expense';
      action = onAddFirst;
    } else if (hasSearchQuery && !hasActiveFilters) {
      title = 'No search results';
      subtitle = 'Try a different search term';
      icon = Icons.search_off;
      actionLabel = 'Clear Search';
      action = onClearFilters;
    } else if (_hasSearchOrFilter) {
      title = 'No filtered results';
      subtitle = 'Try adjusting your search or filters';
      icon = Icons.filter_alt_off;
      actionLabel = 'Clear Filters';
      action = onClearFilters;
    } else {
      title = 'Nothing to show';
      subtitle = 'Your expenses will appear here';
      icon = Icons.receipt_long;
      actionLabel = null;
      action = null;
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 72,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null && actionLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  key: Key('emptyStateAction_$actionLabel'),
                  onPressed: action,
                  icon: Icon(
                    actionLabel == 'Add Your First Expense'
                        ? Icons.add
                        : Icons.clear_all,
                  ),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
