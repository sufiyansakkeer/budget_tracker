import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../domain/entities/expense_history_sort.dart';

/// Bottom sheet for selecting a sort option.
class SortBottomSheet extends StatelessWidget {
  final ExpenseSortOption current;

  const SortBottomSheet({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(
          title: 'Sort by',
          subtitle:
              'Expenses stay grouped by day, newest day first. Sorting '
              'applies within each day.',
        ),
        for (final option in ExpenseSortOption.values)
          RadioListTile<ExpenseSortOption>(
            key: Key('sort_${option.name}'),
            value: option,
            groupValue: current,
            onChanged: (value) => Navigator.pop(context, value),
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: Icon(
              _iconFor(option),
              color: option == current
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(option.label),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  IconData _iconFor(ExpenseSortOption option) {
    switch (option) {
      case ExpenseSortOption.newestFirst:
        return Icons.arrow_downward_rounded;
      case ExpenseSortOption.oldestFirst:
        return Icons.arrow_upward_rounded;
      case ExpenseSortOption.highestAmount:
        return Icons.trending_down_rounded;
      case ExpenseSortOption.lowestAmount:
        return Icons.trending_up_rounded;
      case ExpenseSortOption.category:
        return Icons.category_rounded;
      case ExpenseSortOption.alphabetical:
        return Icons.sort_by_alpha_rounded;
    }
  }
}

/// Helper to show the sort bottom sheet.
Future<ExpenseSortOption?> showSortBottomSheet(
  BuildContext context, {
  required ExpenseSortOption current,
}) {
  return AppBottomSheet.show<ExpenseSortOption>(
    context: context,
    builder: (context) => SortBottomSheet(current: current),
  );
}
