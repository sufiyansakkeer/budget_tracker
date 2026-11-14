import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'safe_to_spend_copy.dart';

/// "Why ₹867.62?": today's target as one division, after what is set aside,
/// opening the full working (blueprint).
class WhyTargetRow extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;
  final VoidCallback onTap;

  const WhyTargetRow({
    super.key = const Key('whyTarget'),
    required this.safeToSpend,
    required this.onTap,
  });

  /// "₹20,823 ÷ 24 days left, after bills and savings".
  static String subtitle(SafeToSpendEntity e) {
    if (e.spendableAtStartOfToday <= 0) {
      return 'Bills and money set aside take everything left';
    }
    final after = [
      if (e.upcomingCommitments > 0) 'bills',
      if ((e.remainingSavingsTarget ?? 0) > 0) 'savings',
      if ((e.reservedAmount ?? 0) > 0) 'money kept aside',
    ];
    final days = e.remainingDays == 1 ? '1 day' : '${e.remainingDays} days';
    final base =
        '${SafeToSpendCopy.amount(e.spendableAtStartOfToday, e.currency)} ÷ '
        '$days left';
    if (after.isEmpty) return base;
    final joined = after.length == 1
        ? after.single
        : '${after.sublist(0, after.length - 1).join(', ')} and ${after.last}';
    return '$base, after $joined';
  }

  @override
  Widget build(BuildContext context) {
    final e = safeToSpend;
    final theme = Theme.of(context);
    final title =
        'Why ${SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency)}?';
    return AppListRow(
      leading: IconTile(
        icon: Icons.pie_chart_outline_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: AppSizes.avatarSm,
      ),
      title: title,
      subtitle: subtitle(e),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      semanticLabel: CurrencyFormatter.forSpeech('$title ${subtitle(e)}'),
      onTap: onTap,
    );
  }
}
