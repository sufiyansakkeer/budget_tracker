import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';

/// A card summarizing a single budget in the list screen.
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
    final accentColor = _accentColor(theme.brightness);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? accentColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _BudgetIcon(budget: budget, accentColor: accentColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            budget.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (budget.isArchived)
                          _StatusTag(
                            label: 'Archived',
                            color: theme.disabledColor,
                          ),
                        if (isActive)
                          _StatusTag(label: 'Active', color: accentColor),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatPeriod(budget),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatAmount(budget.monthlyAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${budget.totalDays} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
  }

  String _formatPeriod(BudgetEntity budget) {
    String two(int n) => n.toString().padLeft(2, '0');
    String d(DateTime x) => '${two(x.day)}/${two(x.month)}/${x.year}';

    return '${d(budget.startDate)} → ${d(budget.endDate)}';
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0);
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
        color: color ?? accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_iconFromString(budget.icon), color: Colors.white, size: 24),
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
        return Icons.beach_access;
      case 'wedding':
        return Icons.favorite;
      case 'business':
        return Icons.business_center;
      case 'personal':
        return Icons.person;
      case 'family':
        return Icons.family_restroom;
      case 'travel':
        return Icons.flight_takeoff;
      case 'home':
        return Icons.home;
      default:
        return Icons.account_balance_wallet;
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
