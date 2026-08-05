import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/expense_history_sort.dart';

/// Bottom sheet for selecting a sort option.
class SortBottomSheet extends StatelessWidget {
  final ExpenseSortOption current;

  const SortBottomSheet({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort by',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...ExpenseSortOption.values.map((option) {
              return ListTile(
                key: Key('sort_${option.name}'),
                leading: Icon(_iconFor(option)),
                title: Text(option.label),
                trailing: option == current
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                selected: option == current,
                onTap: () => Navigator.pop(context, option),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ExpenseSortOption option) {
    switch (option) {
      case ExpenseSortOption.newestFirst:
        return Icons.arrow_downward;
      case ExpenseSortOption.oldestFirst:
        return Icons.arrow_upward;
      case ExpenseSortOption.highestAmount:
        return Icons.trending_down;
      case ExpenseSortOption.lowestAmount:
        return Icons.trending_up;
      case ExpenseSortOption.category:
        return Icons.category;
      case ExpenseSortOption.alphabetical:
        return Icons.sort_by_alpha;
    }
  }
}

/// Helper to show the sort bottom sheet.
Future<ExpenseSortOption?> showSortBottomSheet(
  BuildContext context, {
  required ExpenseSortOption current,
}) {
  return showModalBottomSheet<ExpenseSortOption>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (context) => SortBottomSheet(current: current),
  );
}
