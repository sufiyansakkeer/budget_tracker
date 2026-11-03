import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../domain/entities/settle_rhythm.dart';
import '../../domain/entities/tab_ledger.dart';
import 'tab_tile.dart';
import 'tab_visuals.dart';

/// One settle period of a tab (spec §4): its days, its settle-up day and
/// its total, paid and owed, then its purchases.
class PeriodGroup extends StatelessWidget {
  final PeriodSummary summary;
  final String currency;
  final DateTime today;
  final Map<String, ExpenseCategory> categories;
  final ValueChanged<PurchaseLine> onOpen;

  const PeriodGroup({
    super.key,
    required this.summary,
    required this.currency,
    required this.today,
    required this.categories,
    required this.onOpen,
  });

  /// "Earlier" for the manual-date period before the anchor; "Until 19 Nov"
  /// for a period with no first day yet (a pick-a-date tab with no anchor);
  /// "From 20 Oct" for an open one; "Not scheduled yet" for an open one with
  /// no days at all; otherwise "1 Oct – 7 Oct". Never invents a start date.
  static String label(SettlePeriod period, DateTime today) {
    if (period.isEarlier) return 'Earlier';
    String day(DateTime d) => TabTile.formatDay(d, today: today);
    final start = period.start;
    final end = period.end;
    if (start == null) {
      return end == null ? 'Not scheduled yet' : 'Until ${day(end)}';
    }
    if (end == null) return 'From ${day(start)}';
    return '${day(start)} – ${day(end)}';
  }

  /// When the period settles up. An open period has no settle-up day: a
  /// purchase there is not part of any settle-up yet.
  static String settleLine(SettlePeriod period, DateTime today) {
    final settleUp = period.settleUp;
    if (settleUp == null) return 'No settle-up date yet';
    if (settleUp.isBefore(today)) {
      return 'Settle-up was ${TabTile.formatDay(settleUp, today: today)}';
    }
    // Same "today" / "tomorrow" / date wording as every other surface.
    return 'Settle up ${TabTile.relativeDay(settleUp, today: today)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = summary.period;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String money(double amount) => AppMoney.format(amount, currency: currency);

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label(period, today),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (summary.overdue)
                const StatusChip.tone(
                  label: 'Overdue',
                  tone: AppTone.critical,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(settleLine(period, today), style: muted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Total ${money(summary.total)} · Paid ${money(summary.paid)} · '
            'Owes ${money(summary.owes)}',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppGroupedList(
            children: [
              for (final line in summary.purchases.reversed)
                PurchaseRow(
                  line: line,
                  currency: currency,
                  today: today,
                  categoryName: categories[line.expense.categoryId]?.name,
                  onTap: () => onOpen(line),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A purchase on a tab: what it was, when, its amount and whether it is
/// paid. Tapping it opens the expense.
class PurchaseRow extends StatelessWidget {
  final PurchaseLine line;
  final String currency;
  final DateTime today;
  final String? categoryName;
  final VoidCallback onTap;

  const PurchaseRow({
    super.key,
    required this.line,
    required this.currency,
    required this.today,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final expense = line.expense;
    final (label, tone, icon) = switch (line.status) {
      PurchaseStatus.paid => ('Paid', AppTone.positive, Icons.check_rounded),
      PurchaseStatus.partlyPaid => (
        'Partly paid',
        AppTone.caution,
        Icons.timelapse_rounded,
      ),
      PurchaseStatus.unpaid => (
        'Unpaid',
        AppTone.neutral,
        Icons.radio_button_unchecked_rounded,
      ),
    };
    final day = TabTile.formatDay(expense.date, today: today);
    final subtitle = line.status == PurchaseStatus.partlyPaid
        ? '$day · ${AppMoney.format(line.owes, currency: currency)} left'
        : day;
    final title = purchaseTitle(expense, categoryName: categoryName);
    return KeyedSubtree(
      key: Key('tabPurchase_${expense.id}'),
      child: AppListRow(
        title: title,
        subtitle: subtitle,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMoney(
              amount: expense.amount,
              currency: currency,
              textAlign: TextAlign.end,
            ),
            const SizedBox(height: AppSpacing.xxs),
            StatusChip.tone(label: label, tone: tone, icon: icon),
          ],
        ),
        onTap: onTap,
        semanticLabel:
            '$title, $subtitle, '
            '${AppMoney.format(expense.amount, currency: currency)}, $label',
      ),
    );
  }
}
