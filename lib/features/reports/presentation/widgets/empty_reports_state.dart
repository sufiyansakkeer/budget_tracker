import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';

/// Friendly empty state shown when there are no expenses for the period.
class EmptyReportsState extends StatelessWidget {
  final VoidCallback? onAddExpense;

  /// When true the report is empty because of the active filters.
  final bool filtered;
  final VoidCallback? onClearFilters;

  /// Set when the whole period is before the active budget starts.
  final DateTime? budgetStartsOn;

  /// Set when the whole period is after the active budget ended.
  final DateTime? budgetEndedOn;

  /// Opens the budget switcher, for a period outside the active budget.
  final VoidCallback? onSwitchBudget;

  const EmptyReportsState({
    super.key,
    this.onAddExpense,
    this.filtered = false,
    this.onClearFilters,
    this.budgetStartsOn,
    this.budgetEndedOn,
    this.onSwitchBudget,
  });

  @override
  Widget build(BuildContext context) {
    // Reports cover the active budget only, so neither adding an expense
    // nor clearing filters fills a period outside it.
    final startsOn = budgetStartsOn;
    final endedOn = budgetEndedOn;
    if (startsOn != null || endedOn != null) {
      final day = DateFormat('d MMM');
      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No expenses in this period',
        message: startsOn != null
            ? 'Your active budget starts ${day.format(startsOn)}. Switch '
                  'budget to see earlier spending.'
            : 'Your active budget ended ${day.format(endedOn!)}. Switch '
                  'budget to see later spending.',
        actionLabel: 'Switch budget',
        actionIcon: Icons.swap_horiz_rounded,
        onAction: onSwitchBudget,
      );
    }
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
