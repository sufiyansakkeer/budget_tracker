import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';

/// Displays today's spending against the daily safe-spending allowance with a
/// semantic status (on track / near limit / over).
class TodaySpendingCard extends StatelessWidget {
  final BudgetSummaryEntity summary;

  const TodaySpendingCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = summary.currency;
    final allowance = summary.dailySafeSpending;
    final spent = summary.todaySpending;
    final isOver = summary.todayOverspending > 0;

    final dayRatio = allowance > 0 ? (spent / allowance).clamp(0.0, 1.0) : 0.0;
    final statusColor = _statusColor(isOver);

    final (title, subtitle, icon) = isOver
        ? (
            "You've exceeded today's allowance",
            CurrencyFormatter.format(
              summary.todayOverspending,
              code: currency,
              decimalDigits: 0,
            ),
            Icons.error_rounded,
          )
        : (
            'You can safely spend today',
            CurrencyFormatter.format(
              allowance - spent,
              code: currency,
              decimalDigits: 0,
            ),
            Icons.check_circle_rounded,
          );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Spending",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
                    Icon(icon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel(isOver),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyFormatter.format(
                  spent,
                  code: currency,
                  decimalDigits: 0,
                ),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${CurrencyFormatter.format(allowance, code: currency, decimalDigits: 0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgress(value: dayRatio, showLabel: false),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOver
                      ? '$subtitle over today\'s allowance'
                      : '$subtitle remaining today',
                  style: theme.textTheme.bodyMedium?.copyWith(
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

  Color _statusColor(bool isOver) {
    return isOver ? AppColors.error : AppColors.success;
  }

  String _statusLabel(bool isOver) {
    return isOver ? 'Exceeded' : 'On track';
  }
}

/// Shows the budget date range timeline with a marker at today's position and
/// the number of days remaining.
class BudgetTimelineCard extends StatelessWidget {
  final BudgetSummaryEntity summary;

  const BudgetTimelineCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = summary.startDate;
    final end = summary.endDate;
    final totalDays = end.difference(start).inDays + 1;
    final today = DateTime.now();
    final todayDay = today.difference(start).inDays + 1;
    final progress = totalDays > 0 ? todayDay / totalDays : 0.0;

    final daysRemaining = summary.remainingDays;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Timeline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$daysRemaining days remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMM').format(start),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                DateFormat('d MMM').format(end),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Timeline bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment(progress.clamp(0.0, 1.0) * 2 - 1, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Today',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
