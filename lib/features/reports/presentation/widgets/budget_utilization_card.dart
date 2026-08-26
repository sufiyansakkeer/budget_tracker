import 'package:flutter/material.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';

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

  double get _utilization => widget.monthly <= 0
      ? 0.0
      : (widget.spent / widget.monthly).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppProgress.colorFor(_utilization);
    final utilization = _utilization;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Budget Utilization',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InfoIcon(
                content: InfoContent(
                  title: 'Budget Utilization',
                  whatIsThis:
                      'Shows what percentage of your available budget '
                      'has already been used.',
                  howIsItCalculated:
                      'Utilization = Spent ÷ Budget amount\n\n'
                      'Spent = Total expenses in the budget period\n'
                      'Budget = Your configured budget amount',
                  example:
                      'Budget: ₹30,000\n'
                      'Spent: ₹18,000\n\n'
                      'Utilization: 18,000 ÷ 30,000\n'
                      '= 60%',
                  additionalNotes:
                      '• Color: Green (< 80%), Orange (80–100%), '
                      'Red (> 100%)\n'
                      '• Can exceed 100% when overspending\n'
                      '• Updates when expenses are added or edited',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    AppProgress(value: utilization, height: 10),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Spent: ${CurrencyFormatter.format(widget.spent, code: widget.currency, decimalDigits: 0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      'Remaining: ${CurrencyFormatter.format(widget.remaining, code: widget.currency, decimalDigits: 0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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
        ],
      ),
    );
  }

  IconData _iconFor(double utilization) {
    if (utilization >= 1.0) return Icons.error_outline_rounded;
    if (utilization >= 0.8) return Icons.warning_amber_rounded;
    return Icons.check_circle_rounded;
  }
}
