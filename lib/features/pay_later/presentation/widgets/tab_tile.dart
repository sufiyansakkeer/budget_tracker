import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/theme/app_tone.dart';
import '../../domain/entities/settle_rhythm.dart';
import '../../domain/entities/tab_ledger.dart';
import 'tab_visuals.dart';

/// One tab in a list: name and icon, what it owes (or its credit), when
/// it settles up and an "Overdue" badge when part of it is past due.
class TabTile extends StatelessWidget {
  final TabLedger ledger;
  final VoidCallback? onTap;

  const TabTile({super.key, required this.ledger, this.onTap});

  /// "5 Nov", or "5 Nov 2027" outside [today]'s year.
  static String formatDay(DateTime day, {required DateTime today}) =>
      DateFormat(day.year == today.year ? 'd MMM' : 'd MMM y').format(day);

  /// The one wording every Pay later surface uses for a settle-up day:
  /// "today", "tomorrow", else [formatDay]. [today] comes from the state
  /// being shown (its clock), never from `DateTime.now()` at paint time.
  static String relativeDay(DateTime day, {required DateTime today}) =>
      switch (calendarDaysBetween(today, day)) {
        0 => 'today',
        1 => 'tomorrow',
        _ => formatDay(day, today: today),
      };

  /// "Settle up today", "Settle up tomorrow" or "Settle up 5 Nov". Null
  /// when there is no day, or when [ledger] owes nothing (in credit or
  /// settled: there is nothing to settle).
  static String? settleUpLine(TabLedger ledger) {
    final next = ledger.nextSettleUp;
    if (next == null || ledger.owed <= 0) return null;
    return 'Settle up ${relativeDay(next, today: ledger.asOf)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = ledger.tab;
    final overdue = ledger.overdue > 0;
    final settle = _settleLine();
    final subtitle = [
      if (tab.isArchived) 'Archived',
      if (overdue)
        '${AppMoney.format(ledger.overdue, currency: tab.currency)} overdue',
      ?settle,
    ].join(' · ');

    final Widget balance;
    final String spokenBalance;
    if (ledger.owed > 0) {
      balance = AppMoney(
        amount: ledger.owed,
        currency: tab.currency,
        role: MoneyRole.title,
        textAlign: TextAlign.end,
      );
      spokenBalance =
          'owes ${AppMoney.format(ledger.owed, currency: tab.currency)}';
    } else if (ledger.credit > 0) {
      final credit = AppMoney.format(ledger.credit, currency: tab.currency);
      balance = Text(
        'In credit $credit',
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.end,
      );
      spokenBalance = 'in credit $credit';
    } else {
      final label = ledger.purchases.isEmpty ? 'Nothing yet' : 'Settled';
      balance = Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.end,
      );
      spokenBalance = label.toLowerCase();
    }

    return AppListRow(
      leading: IconTile(
        icon: tabCategoryIcon(tab.category),
        color: theme.colorScheme.primary,
        size: AppSizes.avatarSm,
      ),
      title: tab.name,
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          balance,
          if (overdue) ...[
            const SizedBox(height: AppSpacing.xxs),
            const StatusChip.tone(
              label: 'Overdue',
              tone: AppTone.critical,
              icon: Icons.schedule_rounded,
            ),
          ],
        ],
      ),
      onTap: onTap,
      semanticLabel: [
        tab.name,
        spokenBalance,
        if (subtitle.isNotEmpty) subtitle,
      ].join(', '),
    );
  }

  /// Every rhythm but on demand has a settle-up day unless a manual date
  /// is needed, so there is no "no date" case left.
  String? _settleLine() {
    if (ledger.needsSettleDate) return 'Set your next settle-up date';
    if (ledger.tab.rhythm is OnDemand) return 'Pay when you like';
    return settleUpLine(ledger);
  }
}
