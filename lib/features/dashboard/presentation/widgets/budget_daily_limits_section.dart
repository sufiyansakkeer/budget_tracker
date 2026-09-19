import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/spending_target_status.dart';

/// Section that displays "Today's Safe Spending" with a separate card for
/// each active budget. Amounts are never combined across budgets.
class BudgetDailyLimitsSection extends StatelessWidget {
  final List<BudgetDailyLimitEntity> budgetLimits;

  const BudgetDailyLimitsSection({super.key, required this.budgetLimits});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (budgetLimits.isEmpty) {
      return _EmptyLimitsCard(theme: theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Today's Safe Spending",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InfoIcon(
              content: InfoContent(
                title: "Today's Safe Spending",
                whatIsThis:
                    'How much you can still spend today in each budget '
                    'while staying within that budget for the rest of its '
                    'period. Every budget that is running today gets its '
                    'own card and its own amount.',
                howIsItCalculated:
                    'For each budget:\n'
                    "Today's Safe Spending = Remaining Budget at the start "
                    'of today ÷ Remaining days\n\n'
                    'Remaining Budget at the start of today = Budget amount '
                    '− all expenses before today\n'
                    'Remaining days = days from today to the budget\'s end '
                    'date, counting today\n\n'
                    'Spent Today is the total of that budget\'s expenses '
                    'dated today. Remaining Today = Today\'s Safe Spending '
                    '− Spent Today. The progress bar compares the two.',
                example:
                    'Food budget:\n'
                    'Amount ₹10,000 · Spent ₹2,000 · 20 days left\n'
                    "Today's Safe Spending: ₹8,000 ÷ 20 = ₹400\n\n"
                    'Travel budget:\n'
                    'Amount ₹20,000 · Spent ₹5,000 · 15 days left\n'
                    "Today's Safe Spending: ₹15,000 ÷ 15 = ₹1,000",
                additionalNotes:
                    '• Each budget is independent. Amounts are never added '
                    'together\n'
                    '• Today\'s Safe Spending stays fixed for the day. '
                    'Expenses you add today reduce Remaining Today, and '
                    'tomorrow\'s amount is recalculated from what is left\n'
                    '• Spending less than the safe amount leaves more for '
                    'the remaining days; spending more leaves less\n'
                    '• Status: On track below 80% of the safe amount, Near '
                    'limit at 80–100%, Over limit above 100%\n'
                    '• The smaller bar shows Overall Budget Progress: total '
                    'spent ÷ budget amount for that budget',
                privacyNote:
                    'Your financial data is stored locally on your device.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Per-budget cards
        ...budgetLimits.map(
          (limit) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BudgetDailyLimitCard(budgetLimit: limit),
          ),
        ),
      ],
    );
  }
}

/// Displays Today's Safe Spending for a single budget with context:
/// safe amount, Spent Today, Remaining Today, and on-track/over-limit status.
class BudgetDailyLimitCard extends StatefulWidget {
  final BudgetDailyLimitEntity budgetLimit;

  const BudgetDailyLimitCard({super.key, required this.budgetLimit});

  @override
  State<BudgetDailyLimitCard> createState() => _BudgetDailyLimitCardState();
}

class _BudgetDailyLimitCardState extends State<BudgetDailyLimitCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant BudgetDailyLimitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budgetLimit.dailyLimit != widget.budgetLimit.dailyLimit) {
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
    final bl = widget.budgetLimit;
    final statusColor = _statusColor(bl.status);
    final statusLabel = _statusLabel(bl.status);
    final statusIcon = _statusIcon(bl.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Budget name + status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  bl.budgetName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Today's limit amount (animated)
          Row(
            children: [
              Text(
                "Today's Safe Spending",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final animated = bl.dailyLimit * _controller.value;
                  return Text(
                    CurrencyFormatter.format(
                      animated,
                      code: bl.currency,
                      decimalDigits: 0,
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Spent today / remaining today row
          Row(
            children: [
              Expanded(
                child: _InfoColumn(
                  label: 'Spent Today',
                  amount: bl.spentToday,
                  currency: bl.currency,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _InfoColumn(
                  label: bl.isOverLimit ? 'Over by' : 'Remaining Today',
                  amount: bl.isOverLimit ? bl.exceededToday : bl.remainingToday,
                  currency: bl.currency,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          AppProgress(value: bl.progress, showLabel: false),
          const SizedBox(height: 8),

          // Status message
          Row(
            children: [
              Icon(
                bl.isOverLimit
                    ? Icons.error_rounded
                    : Icons.check_circle_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bl.isOverLimit
                      ? '${CurrencyFormatter.format(bl.exceededToday, code: bl.currency, decimalDigits: 0)} over today\'s safe spending'
                      : '${CurrencyFormatter.format(bl.remainingToday, code: bl.currency, decimalDigits: 0)} left to spend today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Overall budget progress (compact)
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: bl.budgetUtilization.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      bl.budgetUtilization >= 1.0
                          ? AppColors.error
                          : bl.budgetUtilization >= 0.8
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(bl.budgetUtilization * 100).clamp(0, 100).toStringAsFixed(0)}% of budget used',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• ${bl.remainingDays}d left',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(SpendingTargetStatus s) {
    return switch (s) {
      SpendingTargetStatus.onTrack => AppColors.success,
      SpendingTargetStatus.nearLimit => AppColors.warning,
      SpendingTargetStatus.exceeded => AppColors.error,
    };
  }

  String _statusLabel(SpendingTargetStatus s) {
    return switch (s) {
      SpendingTargetStatus.onTrack => 'On track',
      SpendingTargetStatus.nearLimit => 'Near limit',
      SpendingTargetStatus.exceeded => 'Over limit',
    };
  }

  IconData _statusIcon(SpendingTargetStatus s) {
    return switch (s) {
      SpendingTargetStatus.onTrack => Icons.check_circle_rounded,
      SpendingTargetStatus.nearLimit => Icons.warning_amber_rounded,
      SpendingTargetStatus.exceeded => Icons.error_rounded,
    };
  }
}

/// Shown when there are no active budgets.
class _EmptyLimitsCard extends StatelessWidget {
  final ThemeData theme;

  const _EmptyLimitsCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No active budgets',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No budget covers today. Create a budget, or open Budgets\n'
            'to switch to one whose period includes today.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/app/budgets/create'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Budget'),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────

class _InfoColumn extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;

  const _InfoColumn({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyFormatter.format(amount, code: currency, decimalDigits: 0),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
