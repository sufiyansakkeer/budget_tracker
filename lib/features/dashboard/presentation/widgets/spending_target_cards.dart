import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/spending_target_entity.dart';
import '../../domain/entities/spending_target_status.dart';

/// Displays today's spending target with progress bar, status, and exceeded amount.
class DailyTargetCard extends StatelessWidget {
  final SpendingTargetEntity targets;

  const DailyTargetCard({super.key, required this.targets});

  @override
  Widget build(BuildContext context) {
    return _SpendingTargetMiniCard(
      label: 'TODAY',
      target: targets.dailyTarget,
      spent: targets.dailySpent,
      remaining: targets.dailyRemaining,
      exceeded: targets.dailyExceeded,
      progress: targets.dailyProgress,
      status: targets.dailyStatus,
      currency: targets.currency,
    );
  }
}

/// Displays this week's spending target with progress bar, status, and exceeded amount.
class WeeklyTargetCard extends StatelessWidget {
  final SpendingTargetEntity targets;

  const WeeklyTargetCard({super.key, required this.targets});

  @override
  Widget build(BuildContext context) {
    return _SpendingTargetMiniCard(
      label: 'THIS WEEK',
      target: targets.weeklyTarget,
      spent: targets.weeklySpent,
      remaining: targets.weeklyRemaining,
      exceeded: targets.weeklyExceeded,
      progress: targets.weeklyProgress,
      status: targets.weeklyStatus,
      currency: targets.currency,
    );
  }
}

// ── Private shared card ──────────────────────────────────────────────

class _SpendingTargetMiniCard extends StatelessWidget {
  final String label;
  final double target;
  final double spent;
  final double remaining;
  final double exceeded;
  final double progress;
  final SpendingTargetStatus status;
  final String currency;

  const _SpendingTargetMiniCard({
    required this.label,
    required this.target,
    required this.spent,
    required this.remaining,
    required this.exceeded,
    required this.progress,
    required this.status,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(status);
    final isExceeded = status == SpendingTargetStatus.exceeded;

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
          // Header row: label + status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              _StatusChip(status: status),
              const SizedBox(width: 4),
              InfoIcon(content: _infoForLabel(label, currency)),
            ],
          ),
          const SizedBox(height: 14),

          // Target amount
          Text(
            CurrencyFormatter.format(target, code: currency, decimalDigits: 0),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'target',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),

          // Progress bar
          AppProgress(value: progress, showLabel: false),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Spent row
          _InfoRow(
            label: 'Spent',
            amount: spent,
            currency: currency,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),

          if (isExceeded) ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Exceeded by',
              amount: exceeded,
              currency: currency,
              color: AppColors.error,
              isBold: true,
            ),
          ] else ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Remaining',
              amount: remaining,
              currency: currency,
              color: AppColors.success,
              isBold: true,
            ),
          ],
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
}

// ── Helper widgets ──────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          CurrencyFormatter.format(amount, code: currency, decimalDigits: 0),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

InfoContent _infoForLabel(String label, String currency) {
  if (label == 'TODAY') {
    return InfoContent(
      title: "Today's Spending Target",
      whatIsThis:
          "This is the amount you can spend today while staying on track "
          "with your active budget(s).",
      howIsItCalculated:
          'For each active budget: Remaining budget ÷ Remaining days\n'
          'Then all active budgets are combined.',
      example:
          'Budget A remaining: ₹21,000 (20 days left)\n'
          'Daily target A: ₹1,050\n\n'
          'Budget B remaining: ₹8,000 (16 days left)\n'
          'Daily target B: ₹500\n\n'
          'Combined daily target: ₹1,550',
      additionalNotes:
          '• Today is included in the remaining days\n'
          '• The target adjusts each day\n'
          '• Adding expenses reduces the remaining budget, '
          'lowering the target\n'
          '• Status: On Track (< 80%), Near Limit (80–100%), '
          'Exceeded (> 100%)',
    );
  }
  // THIS WEEK
  return InfoContent(
    title: "This Week's Spending Target",
    whatIsThis:
        'The total amount you can spend this week (Monday–Sunday) '
        'while staying on track with your budget.',
    howIsItCalculated:
        'For each active budget: Budget × Days covered this week ÷ '
        'Total budget days\n'
        'Then all active budgets are combined.',
    example:
        'Budget: ₹30,000 for 30 days\n'
        'This week covers 7 days\n'
        'Weekly target: ₹30,000 × 7 ÷ 30 = ₹7,000',
    additionalNotes:
        '• Only budget days that overlap with the current week are counted\n'
        '• If the budget starts/ends mid-week, only the covered days are used\n'
        '• Status: On Track (< 80%), Near Limit (80–100%), '
        'Exceeded (> 100%)',
  );
}

class _StatusChip extends StatelessWidget {
  final SpendingTargetStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      SpendingTargetStatus.onTrack => (
        AppColors.success,
        'On Track',
        Icons.check_circle_rounded,
      ),
      SpendingTargetStatus.nearLimit => (
        AppColors.warning,
        'Near Limit',
        Icons.warning_amber_rounded,
      ),
      SpendingTargetStatus.exceeded => (
        AppColors.error,
        'Over Target',
        Icons.error_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
