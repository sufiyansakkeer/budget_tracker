import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_enums.dart';
import '../../../bills/presentation/pages/bill_widgets.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'safe_to_spend_copy.dart';

/// "Coming up": overdue bills first, then the next unpaid ones, as compact
/// rows, each saying when it is due and which budget pays it. Bills stay one
/// tap away even when there are none.
///
/// An overdue bill says so in words and in the critical tone, and the
/// section names how many are overdue, so the most urgent bill is never
/// missing from Home.
///
/// Only a bill whose occurrence the budget on screen sets aside reads "Set
/// aside" ([setAsideBillIds]): a bill another budget pays names that budget,
/// and one due after the budget ends (or in another currency) names its own,
/// so the row never contradicts the "Free to spend" line above it.
class UpcomingBillsSection extends StatelessWidget {
  final List<BillEntity> bills;

  /// The budget Home is showing.
  final String? activeBudgetId;

  /// Names of the budgets a bill may be linked to, by id.
  final Map<String, String> budgetNames;

  /// Bills whose occurrence the budget on screen sets aside, from its
  /// Today's Safe Spending result.
  final Set<String> setAsideBillIds;

  /// The bills could not be read: the section says so, with [onRetry],
  /// instead of "No bills due soon".
  final bool unavailable;
  final VoidCallback? onRetry;

  /// Some bill exists, perhaps paid or due later: "See all" rather than
  /// "Add bill" even when [bills] is empty.
  final bool hasBills;

  /// Today's Safe Spending of the budget on screen: a bill linked to no
  /// budget says what linking it here would cost each day ([dailyEffect]).
  final SafeToSpendEntity? activeSafeToSpend;

  const UpcomingBillsSection({
    super.key,
    required this.bills,
    this.activeBudgetId,
    this.budgetNames = const {},
    this.setAsideBillIds = const {},
    this.unavailable = false,
    this.onRetry,
    this.hasBills = false,
    this.activeSafeToSpend,
  });

  /// How much less today's amount would be if [bill], linked to no budget,
  /// were linked to [e]'s budget: its amount over the days left, the same
  /// division as today's amount. Null when that budget could not set it
  /// aside (not running, another currency, due after the end) or when the
  /// bill is linked already.
  static double? dailyEffect(BillEntity bill, SafeToSpendEntity? e) {
    if (e == null || bill.budgetId != null || !e.isRunning) return null;
    if (bill.currency != e.currency || e.remainingDays < 1) return null;
    final due = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    if (due.isAfter(e.endDate)) return null;
    return bill.amount / e.remainingDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (unavailable) {
      return AppSection(
        title: 'Coming up',
        action: TextButton(onPressed: onRetry, child: const Text('Try again')),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            "Couldn't load your bills.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final overdue = bills.where((b) => b.status == BillStatus.overdue).length;
    final seeAll = bills.isNotEmpty || hasBills;
    return AppSection(
      title: 'Coming up',
      // Overdue first: money already owed outranks the per-day effects.
      subtitle: overdue == 0
          ? 'By what each does to your daily target'
          : overdue == 1
          ? '1 bill is overdue'
          : '$overdue bills are overdue',
      action: TextButton(
        onPressed: () =>
            context.pushUnique(seeAll ? '/app/bills' : '/app/bills/add'),
        child: Text(seeAll ? 'See all' : 'Add bill'),
      ),
      child: bills.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'No bills due soon. A bill you link to a budget is set '
                'aside before Today\'s Safe Spending is worked out.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : AppGroupedList(
              dividerIndent: AppSizes.avatarSm + AppSpacing.md,
              children: [
                for (final bill in bills)
                  _BillRow(
                    bill: bill,
                    dailyEffect: dailyEffect(bill, activeSafeToSpend),
                    budgetCurrency: activeSafeToSpend?.currency,
                    link: _BillLink.of(
                      bill,
                      activeBudgetId,
                      budgetNames,
                      setAsideBillIds,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// How a bill row describes the budget that pays it.
class _BillLink {
  final String text;
  final String spoken;

  /// Set aside by the budget on screen.
  final bool setAside;

  const _BillLink(this.text, this.spoken, {this.setAside = false});

  static _BillLink of(
    BillEntity bill,
    String? activeBudgetId,
    Map<String, String> budgetNames,
    Set<String> setAsideBillIds,
  ) {
    final budgetId = bill.budgetId;
    if (budgetId == null) {
      return const _BillLink('not linked', 'not linked to a budget');
    }
    if (budgetId == activeBudgetId && setAsideBillIds.contains(bill.id)) {
      return const _BillLink(
        'already set aside',
        'already set aside',
        setAside: true,
      );
    }
    final name = budgetNames[budgetId];
    final text = name == null ? 'paid from another budget' : 'paid from $name';
    return _BillLink(text, text);
  }
}

class _BillRow extends StatelessWidget {
  final BillEntity bill;
  final _BillLink link;
  final double? dailyEffect;
  final String? budgetCurrency;

  const _BillRow({
    required this.bill,
    required this.link,
    this.dailyEffect,
    this.budgetCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = BillVisuals.dueText(bill);
    final overdue = bill.status == BillStatus.overdue;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final effect = dailyEffect == null
        ? null
        : '\u2212${SafeToSpendCopy.amount(dailyEffect!, budgetCurrency!)} a day';
    final effectStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    // What the bill does to today's target (blueprint): nothing when it is
    // already set aside, less a day when it isn't linked, else its amount.
    final Widget trailing = link.setAside
        ? Text(
            'No change',
            textAlign: TextAlign.end,
            style: muted?.copyWith(fontSize: 14),
          )
        : effect != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                effect,
                style: effectStyle?.copyWith(
                  color: context.tone(AppTone.caution).accent,
                ),
              ),
              Text(
                'if paid from this budget',
                textAlign: TextAlign.end,
                style: muted,
              ),
            ],
          )
        : AppMoney(
            amount: bill.amount,
            currency: bill.currency,
            textAlign: TextAlign.end,
          );
    return AppListRow(
      key: ValueKey('upcoming_${bill.id}'),
      leading: IconTile(
        icon: BillVisuals.iconFor(bill.category),
        color: BillVisuals.colorFor(context, bill.status),
        size: AppSizes.avatarSm,
      ),
      title: bill.title,
      subtitleWidget: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: due,
              // Money already owed: the critical tone, as on the Bills list.
              style: overdue
                  ? TextStyle(
                      color: context.tone(AppTone.critical).accent,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
            const TextSpan(text: ' · '),
            TextSpan(
              text: link.text,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      // Capped, so a long effect never squeezes the title at large text.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 112),
        child: trailing,
      ),
      semanticLabel:
          '${bill.title}, $due, ${link.spoken}, '
          '${AppMoney.format(bill.amount, currency: bill.currency)}'
          '${link.setAside
              ? ', no change to the daily target'
              : effect == null
              ? ''
              : ', ${CurrencyFormatter.forSpeech(effect.replaceFirst('\u2212', 'minus '))} if paid from this budget'}',
      onTap: () => context.pushUnique('/app/bills/${bill.id}'),
    );
  }
}
