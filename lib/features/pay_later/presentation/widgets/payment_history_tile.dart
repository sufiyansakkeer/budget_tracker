import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../domain/entities/payment_allocation.dart';
import '../../domain/entities/tab_ledger.dart';
import 'tab_tile.dart';
import 'tab_visuals.dart';

/// One payment on a tab: when, how much, what it covered (the purchases the
/// user chose apart from those paid oldest first), credit it still holds
/// and the tab's balance after it. A tap or long press offers edit and
/// delete.
class PaymentHistoryTile extends StatelessWidget {
  final PaymentLine line;
  final String currency;
  final DateTime today;

  /// The tab's purchases by expense id, to name what was covered.
  final Map<String, PurchaseLine> purchases;
  final Map<String, ExpenseCategory> categories;
  final VoidCallback onActions;

  const PaymentHistoryTile({
    super.key,
    required this.line,
    required this.currency,
    required this.today,
    required this.purchases,
    required this.categories,
    required this.onActions,
  });

  /// "Owed after: X", "Settled" or "In credit after: X" for a signed
  /// balance (> 0 owed, < 0 in credit).
  static String balanceLine(double balance, String currency) {
    final units = MoneyMath.forCurrency(currency).toUnits(balance);
    if (units == 0) return 'Settled';
    final amount = AppMoney.format(balance.abs(), currency: currency);
    return units > 0 ? 'Owed after: $amount' : 'In credit after: $amount';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = line.payment;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final strong = theme.textTheme.labelMedium;
    final chosen = [
      for (final a in line.allocations)
        if (a.isManual) a,
    ];
    final oldestFirst = [
      for (final a in line.allocations)
        if (!a.isManual) a,
    ];
    final unapplied =
        MoneyMath.forCurrency(currency).toUnits(line.unapplied) > 0;
    final note = payment.note?.trim();
    final title = 'Paid ${TabTile.formatDay(payment.paidDate, today: today)}';
    final balance = balanceLine(line.balanceAfter, currency);

    final details = <Widget>[
      if (note != null && note.isNotEmpty) Text(note, style: muted),
      if (chosen.isNotEmpty) ...[
        Text('You chose these', style: strong),
        for (final a in chosen) Text(_covered(a), style: muted),
      ],
      if (oldestFirst.isNotEmpty) ...[
        if (chosen.isNotEmpty)
          Text('The rest paid the oldest first', style: strong),
        for (final a in oldestFirst) Text(_covered(a), style: muted),
      ],
      if (unapplied)
        Text(
          'Held as credit: '
          '${AppMoney.format(line.unapplied, currency: currency)}',
          style: muted,
        ),
      Text(balance, style: strong),
    ];

    return KeyedSubtree(
      key: Key('tabPayment_${payment.id}'),
      child: AppListRow(
        leading: Icon(
          Icons.payments_outlined,
          size: AppSizes.iconMd,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: title,
        subtitleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xxs),
              details[i],
            ],
          ],
        ),
        trailing: AppMoney(
          amount: payment.amount,
          currency: currency,
          textAlign: TextAlign.end,
        ),
        onTap: onActions,
        onLongPress: onActions,
        longPressHint: 'edit or delete',
        semanticLabel: [
          title,
          AppMoney.format(payment.amount, currency: currency),
          if (note != null && note.isNotEmpty) note,
          if (chosen.isNotEmpty) 'you chose ${chosen.map(_covered).join(', ')}',
          if (oldestFirst.isNotEmpty)
            'covered ${oldestFirst.map(_covered).join(', ')}',
          balance,
        ].join(', '),
      ),
    );
  }

  /// "Lunch · 20 Oct · 0.500 OMR".
  String _covered(PaymentAllocation allocation) {
    final purchase = purchases[allocation.expenseId];
    final amount = AppMoney.format(allocation.amount, currency: currency);
    if (purchase == null) return 'A purchase · $amount';
    final expense = purchase.expense;
    final name = purchaseTitle(
      expense,
      categoryName: categories[expense.categoryId]?.name,
    );
    return '$name · ${TabTile.formatDay(expense.date, today: today)} · '
        '$amount';
  }
}
