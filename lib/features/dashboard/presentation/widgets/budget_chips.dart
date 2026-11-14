import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import 'safe_to_spend_copy.dart';
import 'target_ring.dart';

/// Every budget running today as a chip: a small ring of its day, its name
/// and its amount a day. The active one is selected and opens the budget
/// menu (switch, create, manage: [onOpenActive]); tapping another makes it
/// active ([onSelect]). They are Today's title (blueprint): one chip for a
/// single budget.
class BudgetChips extends StatelessWidget {
  final List<BudgetDailyLimitEntity> limits;
  final String? activeBudgetId;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenActive;

  const BudgetChips({
    super.key,
    required this.limits,
    required this.activeBudgetId,
    required this.onSelect,
    required this.onOpenActive,
  });

  @override
  Widget build(BuildContext context) {
    if (limits.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final limit in limits) ...[
            if (limit != limits.first) const SizedBox(width: AppSpacing.sm),
            _BudgetChip(
              key: Key('budget_chip_${limit.budgetId}'),
              limit: limit,
              selected: limit.budgetId == activeBudgetId,
              onTap: limit.budgetId == activeBudgetId
                  ? onOpenActive
                  : () => onSelect(limit.budgetId),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetChip extends StatelessWidget {
  final BudgetDailyLimitEntity limit;
  final bool selected;
  final VoidCallback onTap;

  const _BudgetChip({
    super.key,
    required this.limit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final perDay =
        '${SafeToSpendCopy.safeAmount(limit.dailyLimit, limit.currency)} a day';
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final shape = StadiumBorder(
      side: selected
          ? BorderSide.none
          : BorderSide(color: colorScheme.outlineVariant),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: CurrencyFormatter.forSpeech('${limit.budgetName}, $perDay'),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? colorScheme.primaryContainer : Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 14, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiniTargetRing(
                    spent: limit.spentToday,
                    target: limit.dailyLimit,
                    size: 30,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        limit.budgetName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                      Text(
                        perDay,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? foreground
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
