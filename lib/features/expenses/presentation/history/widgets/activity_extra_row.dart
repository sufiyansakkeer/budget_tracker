import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/dates/date_range_format.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_list.dart';
import '../../../../../core/widgets/app_money.dart';
import '../../../domain/entities/activity_extra.dart';

/// A row in Activity that isn't an expense (blueprint). A tab payment is in
/// secondary ink with "not spending" (the purchases were counted when
/// bought); a budget's start or end is a marker with no amount.
class ActivityExtraRow extends StatelessWidget {
  final ActivityExtra extra;

  /// Opens the tab, for a payment.
  final VoidCallback? onTap;

  const ActivityExtraRow({super.key, required this.extra, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tile = IconTile(
      icon: switch (extra) {
        TabPaymentExtra() => Icons.toll_outlined,
        BudgetMarkerExtra() => Icons.flag_outlined,
      },
      color: muted,
      size: AppSizes.avatarSm,
    );
    switch (extra) {
      case TabPaymentExtra(:final tabName, :final amount, :final currency):
        final at = extra.at;
        // Midnight: the payment's date had no time to show.
        final time = at == DateTime(at.year, at.month, at.day)
            ? null
            : AppDates.time(context, at);
        final money = AppMoney.format(amount, currency: currency);
        return AppListRow(
          leading: tile,
          title: 'Paid $tabName',
          subtitle: time == null
              ? 'Pay later payment'
              : 'Pay later payment · $time',
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppMoney(amount: amount, currency: currency, color: muted),
              Text(
                'not spending',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
          semanticLabel: CurrencyFormatter.forSpeech(
            'Paid $tabName, $money${time == null ? '' : ', $time'}, '
            'a Pay later payment, not spending',
          ),
          onTap: onTap,
        );
      case BudgetMarkerExtra(
        :final name,
        :final started,
        :final amount,
        :final currency,
        :final days,
      ):
        final title = '$name ${started ? 'started' : 'ended'}';
        final detail =
            '${AppMoney.format(amount, currency: currency)} · '
            '$days ${days == 1 ? 'day' : 'days'}';
        return AppListRow(
          leading: tile,
          title: title,
          subtitle: detail,
          semanticLabel: CurrencyFormatter.forSpeech('$title, $detail'),
        );
    }
  }
}
