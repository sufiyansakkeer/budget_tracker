import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

/// Animated radial budget utilization: spent vs remaining vs percentage user.
class BudgetUtilizationCard extends StatefulWidget {
  final double spent;
  final double remaining;
  final double monthly;
  final String currency;

  const BudgetUtilizationCard({
    super.key,
    required this.spent,
    required this.remaining,
    required this.monthly,
    required this.currency,
  });

  @override
  State<BudgetUtilizationCard> createState() => _BudgetUtilizationCardState();
}

class _BudgetUtilizationCardState extends State<BudgetUtilizationCard>
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
  void didUpdateWidget(covariant BudgetUtilizationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spent != widget.spent) {
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
    final utilization = widget.monthly <= 0
        ? 0.0
        : (widget.spent / widget.monthly).clamp(0.0, 1.0);
    final color = _colorFor(utilization);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget Utilization',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final pct = (utilization * 100 * _controller.value)
                        .toStringAsFixed(0);
                    return Text(
                      '$pct%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Spent: ${NumberFormat.currency(symbol: widget.currency, decimalDigits: 0).format(widget.spent)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  'Remaining: ${NumberFormat.currency(symbol: widget.currency, decimalDigits: 0).format(widget.remaining)}',
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
                        value: utilization * _controller.value,
                        strokeWidth: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Icon(_iconFor(utilization), color: color, size: 30),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(double utilization) {
    if (utilization >= 1.0) return AppColors.dangerRed;
    if (utilization >= 0.8) return AppColors.warningOrange;
    return AppColors.safeGreen;
  }

  IconData _iconFor(double utilization) {
    if (utilization >= 1.0) return Icons.error;
    if (utilization >= 0.8) return Icons.warning;
    return Icons.check_circle;
  }
}
