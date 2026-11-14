import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/theme/app_tone.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_money.dart';
import '../../../../budget/domain/entities/safe_to_spend/day_target.dart';
import '../../../../dashboard/presentation/widgets/target_ring.dart';
import '../../../domain/entities/expense_group.dart';
import '../../../../../core/dates/date_range_format.dart';

/// The header above one day's expenses: the day in ink, then what was spent
/// and how many expenses, quietly, at the right. With large text the
/// figures move under the day instead of being cut short.
class ExpenseGroupHeader extends StatelessWidget {
  final ExpenseGroup group;
  final String? currency;

  /// False when the day mixes currencies, so no single total is shown.
  final bool showTotal;

  /// The active budget's target that day (in [currency]): the header then
  /// shows a small ring and what was left or how far over, in place of the
  /// total.
  final DayTarget? dayTarget;

  /// Tab payments and budget markers listed that day, counted as items.
  final int extraCount;

  const ExpenseGroupHeader({
    super.key,
    required this.group,
    this.currency,
    this.showTotal = true,
    this.dayTarget,
    this.extraCount = 0,
  });

  /// Off in goldens, whose fixtures follow the real clock: the date would
  /// change the image every day.
  @visibleForTesting
  static bool dateAfterToday = true;

  /// "Today", "Yesterday", then "Wed 7 Oct" this year and "7 Oct 2025"
  /// before it: the weekday helps more than a year that is obvious.
  static String _dayLabel(ExpenseGroup group, {DateTime? now}) {
    final date = group.date;
    final label = group.label;
    if (date == null) return label;
    // Blueprint: "Today, 8 Oct".
    if (label == 'Today') {
      return dateAfterToday ? 'Today, ${AppDates.dayMonth(date)}' : label;
    }
    if (label == 'Yesterday') return label;
    final year = (now ?? DateTime.now()).year;
    return date.year == year ? AppDates.weekday(date, now: now) : label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = group.expenses.length + extraCount;
    final items = '$count ${count == 1 ? 'item' : 'items'}';
    final total = AppMoney.format(group.totalAmount, currency: currency);
    // Blueprint .dhe: the day 15/700, its result 13/700.
    final muted = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: AppTypography.tabularFigures,
    );
    final day = _dayLabel(group);
    final label = Text(
      day,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final target = dayTarget;
    final over = target != null && target.result < 0;
    final result = target == null
        ? null
        : over
        ? '+${AppMoney.format(-target.result, currency: currency)} over'
        : '${AppMoney.format(target.result, currency: currency, floored: true)} left';
    final figures = Wrap(
      children: [
        // The count is read out, not shown (blueprint).
        if (result != null)
          Text(
            result,
            style: over
                ? muted?.copyWith(color: context.tone(AppTone.caution).accent)
                : muted,
          )
        else if (showTotal)
          Text('Spent $total', style: muted),
      ],
    );
    final spokenTarget = target == null
        ? null
        : over
        ? '$result ${AppMoney.format(target.target, currency: currency, floored: true)}'
        : '$result of ${AppMoney.format(target.target, currency: currency, floored: true)}';
    final stacked = AppSizes.isLargeText(context);
    final ring = target == null
        ? null
        : MiniTargetRing(spent: target.spent, target: target.target, size: 24);

    return Semantics(
      header: true,
      label: CurrencyFormatter.forSpeech(
        spokenTarget != null
            ? '$day, $spokenTarget, $items'
            : '$day, ${showTotal ? 'spent $total, ' : ''}$items',
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xs),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ring == null)
                    label
                  else
                    Row(
                      children: [
                        ring,
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: label),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xxs),
                  figures,
                ],
              )
            : Row(
                children: [
                  if (ring != null) ...[
                    ring,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(child: label),
                  const SizedBox(width: AppSpacing.sm),
                  figures,
                ],
              ),
      ),
    );
  }
}
