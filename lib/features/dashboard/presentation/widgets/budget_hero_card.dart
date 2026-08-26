import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';

/// The primary hero card on the dashboard. Highlights "today's safe spending"
/// as the main number, with budget-used progress and a status message.
class BudgetHeroCard extends StatefulWidget {
  final BudgetSummaryEntity summary;

  const BudgetHeroCard({super.key, required this.summary});

  @override
  State<BudgetHeroCard> createState() => _BudgetHeroCardState();
}

class _BudgetHeroCardState extends State<BudgetHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant BudgetHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.dailySafeSpending !=
        widget.summary.dailySafeSpending) {
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
    final summary = widget.summary;
    final currency = summary.currency;
    final isOver = summary.todayOverspending > 0;

    final (statusLabel, statusIcon) = _statusInfo(isOver);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        "Today's Safe Spending",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InfoIcon(
                      content: InfoContent(
                        title: "Today's Safe Spending",
                        whatIsThis:
                            "This is the amount you can safely spend today "
                            "while staying on track with your active budget.",
                        howIsItCalculated:
                            'Remaining budget ÷ Remaining days\n\n'
                            'The remaining budget is calculated by subtracting '
                            'total expenses from your budget amount. Remaining '
                            'days include today through the budget end date.',
                        example:
                            'Budget: ₹30,000\n'
                            'Spent: ₹9,000\n'
                            'Remaining budget: ₹21,000\n'
                            'Remaining days: 20\n\n'
                            'Safe spending: ₹21,000 ÷ 20\n'
                            '= ₹1,050 per day',
                        additionalNotes:
                            '• Changes when you add, edit, or delete expenses\n'
                            '• Unused allowance is not removed — it rolls into '
                            'the next day\n'
                            '• Multiple active budgets are combined\n'
                            '• Adjusts automatically each day',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final animated = summary.dailySafeSpending * _controller.value;
              return Text(
                CurrencyFormatter.format(animated, code: currency),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            summary.todayOverspending > 0
                ? "You've exceeded today's allowance"
                : 'You can safely spend today',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          // Budget progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: summary.budgetUtilization.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      summary.budgetUtilization >= 1.0
                          ? Colors.white
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(summary.budgetUtilization * 100).clamp(0, 100).toStringAsFixed(0)}% used',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, IconData) _statusInfo(bool isOver) {
    return isOver
        ? ('Exceeded', Icons.error_rounded)
        : ('On track', Icons.check_circle_rounded);
  }
}

/// Compact summary of Budget / Spent / Remaining.
class BudgetOverviewCard extends StatelessWidget {
  final BudgetSummaryEntity summary;

  const BudgetOverviewCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = summary.currency;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Metric(
                label: 'Budget',
                amount: summary.monthlyAmount,
                currency: currency,
                color: theme.colorScheme.onSurface,
              ),
              const _MetricDivider(),
              _Metric(
                label: 'Spent',
                amount: summary.totalSpent,
                currency: currency,
                color: AppColors.primary,
              ),
              const _MetricDivider(),
              _Metric(
                label: 'Remaining',
                amount: summary.remainingBudget,
                currency: currency,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppProgress(
                  value: summary.budgetUtilization,
                  showLabel: true,
                ),
              ),
              const SizedBox(width: 8),
              InfoIcon(
                content: InfoContent(
                  title: 'Budget Progress',
                  whatIsThis:
                      'Shows how much of your budget has been used so far '
                      'and how much remains.',
                  howIsItCalculated:
                      'Progress = Total spent ÷ Budget amount\n'
                      'Remaining = Budget amount − Total spent',
                  example:
                      'Budget: ₹30,000\n'
                      'Spent: ₹18,000\n'
                      'Remaining: ₹12,000\n'
                      'Progress: 18,000 ÷ 30,000 = 60%',
                  additionalNotes:
                      '• The progress bar shows ≤ 100% even when over budget\n'
                      '• Color changes: green (< 80%), orange (80–100%), '
                      'red (> 100%)\n'
                      '• Updates automatically when expenses are added '
                      'or edited',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;

  const _Metric({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(amount, code: currency),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
