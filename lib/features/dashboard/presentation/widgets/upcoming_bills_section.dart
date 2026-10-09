import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/presentation/pages/bill_widgets.dart';

/// "Coming up": the next unpaid bills as compact rows, each saying when it
/// is due and which budget pays it. Bills stay one tap away even when there
/// are none.
///
/// Only a bill linked to the budget on screen reads "Set aside": a bill
/// another budget pays names that budget, so the row never contradicts the
/// "Free to spend" line above it.
class UpcomingBillsSection extends StatelessWidget {
  final List<BillEntity> bills;

  /// The budget Home is showing.
  final String? activeBudgetId;

  /// Names of the budgets a bill may be linked to, by id.
  final Map<String, String> budgetNames;

  const UpcomingBillsSection({
    super.key,
    required this.bills,
    this.activeBudgetId,
    this.budgetNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSection(
      title: 'Coming up',
      action: TextButton(
        onPressed: () =>
            context.pushUnique(bills.isEmpty ? '/app/bills/add' : '/app/bills'),
        child: Text(bills.isEmpty ? 'Add bill' : 'See all'),
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
              dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
              children: [
                for (final bill in bills)
                  _BillRow(
                    bill: bill,
                    link: _BillLink.of(bill, activeBudgetId, budgetNames),
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
  ) {
    final budgetId = bill.budgetId;
    if (budgetId == null) {
      return const _BillLink('Not linked', 'not linked to a budget');
    }
    if (budgetId == activeBudgetId) {
      return const _BillLink('Set aside', 'set aside', setAside: true);
    }
    final name = budgetNames[budgetId];
    final text = name == null ? 'Paid from another budget' : 'Paid from $name';
    return _BillLink(text, text.toLowerCase());
  }
}

class _BillRow extends StatelessWidget {
  final BillEntity bill;
  final _BillLink link;

  const _BillRow({required this.bill, required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = BillVisuals.dueText(bill);
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
            TextSpan(text: '$due · '),
            TextSpan(
              text: link.text,
              style: TextStyle(
                color: link.setAside
                    ? context.tone(AppTone.positive).accent
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: AppMoney(
        amount: bill.amount,
        currency: bill.currency,
        textAlign: TextAlign.end,
      ),
      semanticLabel:
          '${bill.title}, $due, ${link.spoken}, '
          '${AppMoney.format(bill.amount, currency: bill.currency)}',
      onTap: () => context.pushUnique('/app/bills/${bill.id}'),
    );
  }
}
