import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/contrast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';

/// One expense as a list row, the same on Home and in Expenses.
///
/// Category tile, what it was (the note, or the category), a second line
/// with the category and when, and the amount at the right edge. Spending
/// carries no sign. The category may be shortened to fit; the time never
/// is. In a combined view a small tag names the expense's budget.
class TransactionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  /// First part of the second line, shortened when space runs out
  /// (usually the category). Null when the title already is the category.
  final String? detail;

  /// Second part of the second line, always shown whole ("12:40 PM").
  final String when;

  final double amount;
  final String? currency;
  final bool hasReceipt;

  /// The expense's budget, tagged in a view of several budgets.
  final String? budgetName;

  /// A trailing icon button (e.g. budget details in a combined view).
  final Widget? action;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String semanticLabel;

  const TransactionRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    required this.when,
    required this.amount,
    required this.currency,
    this.hasReceipt = false,
    this.budgetName,
    this.action,
    this.onTap,
    this.onLongPress,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final large = MediaQuery.textScalerOf(context).scale(12) > 18;
    final receipt = hasReceipt
        ? Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Icon(
              Icons.receipt_long_rounded,
              size: AppSizes.iconXs,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : null;
    return AppListRow(
      leading: IconTile(icon: icon, color: color, size: AppSizes.avatarSm),
      title: title,
      subtitleWidget: large
          // With large text the parts wrap rather than squeeze.
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // The separator ends the first part, so a wrapped line
                // never starts with it.
                if (detail != null) Text('$detail · ', style: muted),
                Text(when, style: muted),
                ?receipt,
                if (budgetName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _BudgetTag(name: budgetName!),
                  ),
              ],
            )
          : Row(
              children: [
                if (detail != null)
                  Flexible(
                    child: Text(
                      detail!,
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  detail != null ? ' · $when' : when,
                  style: muted,
                  maxLines: 1,
                ),
                ?receipt,
                if (budgetName != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: _BudgetTag(name: budgetName!)),
                ],
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AppMoney(
              amount: amount,
              currency: currency,
              textAlign: TextAlign.end,
            ),
          ),
          ?action,
        ],
      ),
      semanticLabel: semanticLabel,
      longPressHint: 'more actions',
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _BudgetTag extends StatelessWidget {
  final String name;

  const _BudgetTag({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surfaceContainerHigh;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Contrast.ensureContrast(
              theme.colorScheme.onSurfaceVariant,
              fill,
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
