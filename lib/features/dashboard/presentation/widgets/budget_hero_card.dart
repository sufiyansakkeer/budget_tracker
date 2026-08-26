import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../../domain/entities/spending_target_entity.dart';
import '../../domain/entities/spending_target_status.dart';

/// The primary hero card on the dashboard. Displays "Today's Spending Limit"
/// as the main number, sourced from [SpendingTargetEntity] — the single source
/// of truth across the app.
class BudgetHeroCard extends StatefulWidget {
  final BudgetSummaryEntity summary;
  final SpendingTargetEntity? spendingTarget;

  const BudgetHeroCard({
    super.key,
    required this.summary,
    this.spendingTarget,
  });

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
    final oldLimit = oldWidget.spendingTarget?.dailyTarget ?? 0;
    final newLimit = widget.spendingTarget?.dailyTarget ?? 0;
    if (oldLimit != newLimit) {
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
    final spendingTarget = widget.spendingTarget;
    final currency = summary.currency;

    // Use SpendingTargetEntity as single source of truth.
    final dailyLimit = spendingTarget?.dailyTarget ?? 0.0;
    final isOver =
        spendingTarget?.dailyStatus == SpendingTargetStatus.exceeded;
    final isNearLimit =
        spendingTarget?.dailyStatus == SpendingTargetStatus.nearLimit;

    final (statusLabel, statusIcon) = _statusInfo(isOver, isNearLimit);

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
                    const Flexible(
                      child: Text(
                        "Today's Spending Limit",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InfoIcon(
                      content: InfoContent(
                        title: "Today's Spending Limit",
                        whatIsThis:
                            "This is the maximum amount you can spend today "
                            "while staying on track with your active budgets.",
                        howIsItCalculated:
                            'For each active budget: Remaining budget ÷ Remaining days\n'
                            'Then all active budgets are combined.',
                        example:
                            'Budget A remaining: ₹21,000 (20 days left)\n'
                            'Daily limit A: ₹1,050\n\n'
                            'Budget B remaining: ₹8,000 (16 days left)\n'
                            'Daily limit B: ₹500\n\n'
                            'Combined limit: ₹1,550',
                        additionalNotes:
                            '• Today is included in the remaining days\n'
                            '• The limit adjusts each day\n'
                            '• Adding expenses reduces the remaining budget, '
                            'lowering the limit\n'
                            '• Unused allowance rolls into the next day',
                        privacyNote:
                            'Your financial data is stored locally on your device.',
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
              final animated = dailyLimit * _controller.value;
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
            isOver
                ? "You've exceeded today's spending limit"
                : 'You can safely spend this much today',
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
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
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

  (String, IconData) _statusInfo(bool isOver, bool isNearLimit) {
    if (isOver) return ('Over limit', Icons.error_rounded);
    if (isNearLimit) return ('Near limit', Icons.warning_amber_rounded);
    return ('On track', Icons.check_circle_rounded);
  }
}

/// Compact summary of Budget / Spent / Remaining.
class BudgetOverviewCard extends StatelessWidget {
  final BudgetSummaryEntity summary;
  final SpendingTargetEntity? spendingTarget;

  const BudgetOverviewCard({
    super.key,
    required this.summary,
    this.spendingTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = summary.currency;
    final dailySpent = spendingTarget?.dailySpent ?? summary.todaySpending;
    final dailyLimit = spendingTarget?.dailyTarget ?? summary.dailySafeSpending;
    final dailyRemaining = (dailyLimit - dailySpent).clamp(0.0, double.infinity);

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
                label: 'Remaining Budget',
                amount: summary.remainingBudget,
                currency: currency,
                color: AppColors.success,
              ),
              const _MetricDivider(),
              _Metric(
                label: 'Spent Today',
                amount: dailySpent,
                currency: currency,
                color: theme.colorScheme.onSurface,
              ),
              const _MetricDivider(),
              _Metric(
                label: 'Remaining Today',
                amount: dailyRemaining,
                currency: currency,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: summary.budgetUtilization.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    summary.budgetUtilization >= 1.0
                        ? AppColors.error
                        : summary.budgetUtilization >= 0.8
                            ? AppColors.warning
                            : AppColors.success,
                  ),
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
