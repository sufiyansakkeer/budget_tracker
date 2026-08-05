import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_history_filter.dart';

/// Displays the currently active filters as chips with remove actions.
class ActiveFilterChips extends StatelessWidget {
  final ExpenseHistoryFilter filter;
  final List<ExpenseCategory> categories;
  final ValueChanged<ExpenseHistoryFilter> onChanged;

  const ActiveFilterChips({
    super.key,
    required this.filter,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filter.categoryId != null) {
      final category = categories
          .where((c) => c.id == filter.categoryId)
          .toList();
      final name = category.isNotEmpty
          ? category.first.name
          : filter.categoryId!;
      chips.add(
        _chip(
          label: name,
          onDeleted: () => onChanged(filter.copyWithCategory(null)),
        ),
      );
    }

    if (filter.dateFrom != null) {
      chips.add(
        _chip(
          label:
              'From ${filter.dateFrom!.day}/${filter.dateFrom!.month}/${filter.dateFrom!.year}',
          onDeleted: () => onChanged(filter.copyWithDateFrom(null)),
        ),
      );
    }

    if (filter.dateTo != null) {
      chips.add(
        _chip(
          label:
              'To ${filter.dateTo!.day}/${filter.dateTo!.month}/${filter.dateTo!.year}',
          onDeleted: () => onChanged(filter.copyWithDateTo(null)),
        ),
      );
    }

    if (filter.minAmount != null) {
      chips.add(
        _chip(
          label: 'Min ${filter.minAmount!.toStringAsFixed(0)}',
          onDeleted: () => onChanged(filter.copyWithMinAmount(null)),
        ),
      );
    }

    if (filter.maxAmount != null) {
      chips.add(
        _chip(
          label: 'Max ${filter.maxAmount!.toStringAsFixed(0)}',
          onDeleted: () => onChanged(filter.copyWithMaxAmount(null)),
        ),
      );
    }

    for (final tag in filter.tags) {
      chips.add(
        _chip(
          label: tag,
          onDeleted: () => onChanged(filter.copyWithoutTag(tag)),
        ),
      );
    }

    if (filter.receiptOnly) {
      chips.add(
        _chip(
          label: 'Receipt',
          onDeleted: () => onChanged(filter.copyWithReceiptOnly(false)),
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }

  Widget _chip({required String label, required VoidCallback onDeleted}) {
    return InputChip(
      key: ValueKey('activeFilter_$label'),
      label: Text(label),
      onDeleted: onDeleted,
      deleteButtonTooltipMessage: 'Remove $label filter',
      visualDensity: VisualDensity.compact,
    );
  }
}
