import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

/// Friendly empty state shown when there are no expenses for the period.
class EmptyReportsState extends StatelessWidget {
  final VoidCallback? onAddExpense;

  /// When true the report is empty because of the active filters.
  final bool filtered;
  final VoidCallback? onClearFilters;

  const EmptyReportsState({
    super.key,
    this.onAddExpense,
    this.filtered = false,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (filtered) {
      return EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Nothing matches these filters',
        message:
            'Try a wider date range or clear the filters to see the '
            'full report.',
        actionLabel: 'Clear filters',
        actionIcon: Icons.clear_all_rounded,
        onAction: onClearFilters,
      );
    }
    return EmptyState(
      icon: Icons.insights_rounded,
      title: 'No expenses in this period',
      message:
          'Charts, patterns and insights appear once you record '
          'expenses in the selected period.',
      actionLabel: 'Add expense',
      actionIcon: Icons.add_rounded,
      onAction: onAddExpense,
    );
  }
}
