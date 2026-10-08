import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_money.dart';
import '../../../domain/entities/expense_group.dart';

/// The header above one day's expenses: the day in ink, then what was spent
/// and how many expenses, quietly, at the right. With large text the
/// figures move under the day instead of being cut short.
class ExpenseGroupHeader extends StatelessWidget {
  final ExpenseGroup group;
  final String? currency;

  /// False when the day mixes currencies, so no single total is shown.
  final bool showTotal;

  const ExpenseGroupHeader({
    super.key,
    required this.group,
    this.currency,
    this.showTotal = true,
  });

  /// "Today", "Yesterday", then "Wed 7 Oct" this year and "7 Oct 2025"
  /// before it: the weekday helps more than a year that is obvious.
  static String _dayLabel(ExpenseGroup group, {DateTime? now}) {
    final date = group.date;
    final label = group.label;
    if (date == null || label == 'Today' || label == 'Yesterday') return label;
    final year = (now ?? DateTime.now()).year;
    return date.year == year ? DateFormat('EEE d MMM').format(date) : label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = group.expenses.length;
    final items = '$count ${count == 1 ? 'item' : 'items'}';
    final total = AppMoney.format(group.totalAmount, currency: currency);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: AppTypography.tabularFigures,
    );
    final day = _dayLabel(group);
    final label = Text(
      day,
      style: theme.textTheme.titleSmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final figures = Wrap(
      children: [
        if (showTotal) ...[
          Text('Spent $total', style: muted),
          Text(' · ', style: muted),
        ],
        Text(items, style: muted),
      ],
    );
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;

    return Semantics(
      header: true,
      label: '$day, ${showTotal ? 'spent $total, ' : ''}$items',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xs),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: AppSpacing.xxs),
                  figures,
                ],
              )
            : Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: AppSpacing.sm),
                  figures,
                ],
              ),
      ),
    );
  }
}
