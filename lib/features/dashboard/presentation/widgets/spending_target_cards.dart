import 'package:flutter/material.dart';

import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/spending_target_entity.dart';
import '../../domain/entities/spending_target_status.dart';

/// Shows today's spending progress: spent vs limit, remaining, and status.
///
/// This replaces the old [DailyTargetCard] which confusingly showed "target"
/// as a separate competing number. Now it focuses on what has actually
/// happened today against the single spending limit shown in the hero card.
class TodayProgressCard extends StatelessWidget {
  final SpendingTargetEntity targets;

  const TodayProgressCard({super.key, required this.targets});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final theme = Theme.of(context);
    final statusColor = _statusColor(targets.dailyStatus, appColors: appColors);
    final isExceeded = targets.dailyStatus == SpendingTargetStatus.exceeded;
    final statusLabel = _statusLabel(targets.dailyStatus);
    final statusIcon = _statusIcon(targets.dailyStatus);

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Today',
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
          const SizedBox(height: 16),

          // Spent / Limit / Remaining row
          Row(
            children: [
              Expanded(
                child: _InfoColumn(
                  label: 'Spent',
                  amount: targets.dailySpent,
                  currency: targets.currency,
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
                  label: isExceeded ? 'Over limit' : 'Remaining',
                  amount: isExceeded
                      ? targets.dailyExceeded
                      : targets.dailyRemaining,
                  currency: targets.currency,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          AppProgress(value: targets.dailyProgress, showLabel: false),
          const SizedBox(height: 8),

          // Status message
          Row(
            children: [
              Icon(
                isExceeded ? Icons.error_rounded : Icons.check_circle_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isExceeded
                      ? '₹${CurrencyFormatter.format(targets.dailyExceeded, code: targets.currency, decimalDigits: 0)} over today\'s limit'
                      : '₹${CurrencyFormatter.format(targets.dailyRemaining, code: targets.currency, decimalDigits: 0)} left today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(SpendingTargetStatus s, {AppColorTokens? appColors}) {
    return switch (s) {
      SpendingTargetStatus.onTrack => appColors?.success ?? appColors?.success ?? const Color(0xFF239B70),
      SpendingTargetStatus.nearLimit => appColors?.warning ?? appColors?.warning ?? const Color(0xFFD89432),
      SpendingTargetStatus.exceeded => appColors?.error ?? appColors?.error ?? const Color(0xFFD65C62),
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

/// Displays this week's spending target with progress bar, status, and exceeded amount.
class WeeklyTargetCard extends StatelessWidget {
  final SpendingTargetEntity targets;

  const WeeklyTargetCard({super.key, required this.targets});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final theme = Theme.of(context);
    final statusColor = _statusColor(targets.weeklyStatus, appColors: appColors);
    final isExceeded = targets.weeklyStatus == SpendingTargetStatus.exceeded;
    final statusLabel = _statusLabel(targets.weeklyStatus);
    final statusIcon = _statusIcon(targets.weeklyStatus);

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
                  'This Week',
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
              const SizedBox(width: 4),
              InfoIcon(content: _weeklyInfoContent(targets.currency)),
            ],
          ),
          const SizedBox(height: 14),

          // Target amount
          Text(
            CurrencyFormatter.format(
              targets.weeklyTarget,
              code: targets.currency,
              decimalDigits: 0,
            ),
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
          AppProgress(value: targets.weeklyProgress, showLabel: false),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(targets.weeklyProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
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
            amount: targets.weeklySpent,
            currency: targets.currency,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),

          if (isExceeded) ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Exceeded by',
              amount: targets.weeklyExceeded,
              currency: targets.currency,
              color: context.appColors.error,
              isBold: true,
            ),
          ] else ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Remaining',
              amount: targets.weeklyRemaining,
              currency: targets.currency,
              color: context.appColors.success,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(SpendingTargetStatus s, {AppColorTokens? appColors}) {
    return switch (s) {
      SpendingTargetStatus.onTrack => appColors?.success ?? appColors?.success ?? const Color(0xFF239B70),
      SpendingTargetStatus.nearLimit => appColors?.warning ?? appColors?.warning ?? const Color(0xFFD89432),
      SpendingTargetStatus.exceeded => appColors?.error ?? appColors?.error ?? const Color(0xFFD65C62),
    };
  }

  String _statusLabel(SpendingTargetStatus s) {
    return switch (s) {
      SpendingTargetStatus.onTrack => 'On track',
      SpendingTargetStatus.nearLimit => 'Near limit',
      SpendingTargetStatus.exceeded => 'Over target',
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

// ── Helper widgets ──────────────────────────────────────────────────

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
        Text(
          CurrencyFormatter.format(amount, code: currency, decimalDigits: 0),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

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

InfoContent _weeklyInfoContent(String currency) {
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
