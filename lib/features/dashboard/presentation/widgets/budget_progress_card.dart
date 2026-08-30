import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';

class BudgetProgressCard extends StatefulWidget {
  final double budgetUtilization;
  final double totalSpent;
  final double remainingBudget;
  final String currency;

  const BudgetProgressCard({
    super.key,
    required this.budgetUtilization,
    required this.totalSpent,
    required this.remainingBudget,
    required this.currency,
  });

  @override
  State<BudgetProgressCard> createState() => _BudgetProgressCardState();
}

class _BudgetProgressCardState extends State<BudgetProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant BudgetProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budgetUtilization != widget.budgetUtilization) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (widget.budgetUtilization * 100).clamp(0.0, 100.0);
    final color = _getProgressColor(percentage);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget Used',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final animatedPercentage = percentage * _controller.value;
                    return Text(
                      '${animatedPercentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Spent: ${CurrencyFormatter.format(widget.totalSpent, code: widget.currency, decimalDigits: 0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  'Remaining: ${CurrencyFormatter.format(widget.remainingBudget, code: widget.currency, decimalDigits: 0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value:
                            widget.budgetUtilization.clamp(0.0, 1.0) *
                            _controller.value,
                        strokeWidth: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Icon(_getProgressIcon(percentage), color: color, size: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) return AppColors.dangerRed;
    if (percentage >= 80) return AppColors.warningOrange;
    return AppColors.safeGreen;
  }

  IconData _getProgressIcon(double percentage) {
    if (percentage >= 100) return Icons.error;
    if (percentage >= 80) return Icons.warning;
    return Icons.check_circle;
  }
}
