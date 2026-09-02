import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// A card summarizing a single budget in the list screen.
///
/// Shows the budget's remaining amount prominently, together with its amount,
/// period, utilization progress, and an active indicator.
class BudgetCard extends StatelessWidget {
  final BudgetEntity budget;
  final bool isActive;
  final VoidCallback? onTap;

  const BudgetCard({
    super.key,
    required this.budget,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _accentColor(context, theme.brightness);

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppSpacing.borderRadiusLg,
        border: isActive ? Border.all(color: accentColor, width: 1.5) : null,
      ),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _BudgetIcon(budget: budget, accentColor: accentColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              budget.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (budget.isArchived) ...[
                            const SizedBox(width: AppSpacing.xs),
                            _StatusTag(
                              label: 'Archived',
                              color: theme.disabledColor,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _formatPeriod(budget),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive) _ActiveBadge(color: accentColor),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        CurrencyFormatter.format(
                          budget.monthlyAmount,
                          code: budget.currency,
                          decimalDigits: 0,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        CurrencyFormatter.format(
                          budget.monthlyAmount - budget.remainingAmount,
                          code: budget.currency,
                          decimalDigits: 0,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.appColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        CurrencyFormatter.format(
                          budget.remainingAmount,
                          code: budget.currency,
                          decimalDigits: 0,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.appColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: AppProgress(value: _utilization(budget))),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${(_utilization(budget) * 100).toStringAsFixed(0)}% used',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _utilization(BudgetEntity budget) {
    if (budget.monthlyAmount <= 0) return 0;
    final used = budget.monthlyAmount - budget.remainingAmount;
    return used / budget.monthlyAmount;
  }

  Color _accentColor(BuildContext context, Brightness brightness) {
    return brightness == Brightness.dark
        ? context.appColors.primaryLight
        : context.appColors.primary;
  }

  String _formatPeriod(BudgetEntity budget) {
    String two(int n) => n.toString().padLeft(2, '0');
    String d(DateTime x) => '${two(x.day)}/${two(x.month)}/${x.year}';

    return '${d(budget.startDate)} → ${d(budget.endDate)}';
  }
}

class _BudgetIcon extends StatelessWidget {
  final BudgetEntity budget;
  final Color accentColor;

  const _BudgetIcon({required this.budget, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(budget.color);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: (color ?? accentColor).withValues(alpha: 0.15),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Icon(
        _iconFromString(budget.icon),
        color: color ?? accentColor,
        size: 24,
      ),
    );
  }

  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  IconData _iconFromString(String? icon) {
    switch (icon) {
      case 'vacation':
        return Icons.beach_access_rounded;
      case 'wedding':
        return Icons.favorite_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'personal':
        return Icons.person_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'home':
        return Icons.home_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}

class _ActiveBadge extends StatelessWidget {
  final Color color;

  const _ActiveBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
