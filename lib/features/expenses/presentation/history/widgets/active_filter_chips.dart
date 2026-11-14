import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/currency/money_input.dart';
import '../../../../../core/widgets/app_money.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_history_filter.dart';
import 'quick_filter_chips.dart';
import '../../../../../core/dates/date_range_format.dart';

/// Displays the currently active filters as removable chips.
class ActiveFilterChips extends StatelessWidget {
  final ExpenseHistoryFilter filter;
  final List<ExpenseCategory> categories;
  final ValueChanged<ExpenseHistoryFilter> onChanged;

  /// The currency the amount bounds are in; null when the view mixes
  /// currencies, where they are plain numbers.
  final String? currency;

  const ActiveFilterChips({
    super.key,
    required this.filter,
    required this.categories,
    required this.onChanged,
    this.currency,
  });

  String _amount(double value) => currency == null
      ? MoneyInput.forInput(value)
      : AppMoney.format(value, currency: currency);

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filter.categoryId != null) {
      final match = categories.where((c) => c.id == filter.categoryId);
      final name = match.isNotEmpty ? match.first.name : filter.categoryId!;
      chips.add(
        _chip(
          label: name,
          onDeleted: () => onChanged(filter.copyWithCategory(null)),
        ),
      );
    }

    final preset = QuickDatePreset.of(filter);
    if (preset != null) {
      chips.add(
        _chip(
          label: preset.label,
          onDeleted: () =>
              onChanged(filter.copyWithDateFrom(null).copyWithDateTo(null)),
        ),
      );
    } else if (filter.dateFrom != null && filter.dateTo != null) {
      // A custom range reads as one chip: "12 – 15 Mar".
      chips.add(
        _chip(
          label: AppDates.span(filter.dateFrom!, filter.dateTo!),
          onDeleted: () =>
              onChanged(filter.copyWithDateRange(from: null, to: null)),
        ),
      );
    } else {
      if (filter.dateFrom != null) {
        chips.add(
          _chip(
            label: 'From ${AppDates.day(filter.dateFrom!)}',
            onDeleted: () => onChanged(filter.copyWithDateFrom(null)),
          ),
        );
      }
      if (filter.dateTo != null) {
        chips.add(
          _chip(
            label: 'To ${AppDates.day(filter.dateTo!)}',
            onDeleted: () => onChanged(filter.copyWithDateTo(null)),
          ),
        );
      }
    }

    if (filter.minAmount != null) {
      chips.add(
        _chip(
          label: 'Min ${_amount(filter.minAmount!)}',
          onDeleted: () => onChanged(filter.copyWithMinAmount(null)),
        ),
      );
    }

    if (filter.maxAmount != null) {
      chips.add(
        _chip(
          label: 'Max ${_amount(filter.maxAmount!)}',
          onDeleted: () => onChanged(filter.copyWithMaxAmount(null)),
        ),
      );
    }

    for (final tag in filter.tags) {
      chips.add(
        _chip(
          label: '#$tag',
          onDeleted: () => onChanged(filter.copyWithoutTag(tag)),
        ),
      );
    }

    if (filter.kind != ExpenseKind.all) {
      chips.add(
        _chip(
          label: '${filter.kind.label} only',
          onDeleted: () => onChanged(filter.copyWithKind(ExpenseKind.all)),
        ),
      );
    }

    if (filter.receiptOnly) {
      chips.add(
        _chip(
          label: 'Has receipt',
          onDeleted: () => onChanged(filter.copyWithReceiptOnly(false)),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: chips,
      ),
    );
  }

  Widget _chip({required String label, required VoidCallback onDeleted}) {
    return InputChip(
      key: ValueKey('activeFilter_$label'),
      label: Text(label),
      onDeleted: onDeleted,
      deleteIconColor: null,
      deleteButtonTooltipMessage: CurrencyFormatter.forSpeech(
        'Remove $label filter',
      ),
    );
  }
}
