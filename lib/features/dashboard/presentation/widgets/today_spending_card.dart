import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
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
    final statusLabel = isOver ? 'Exceeded' : 'On Track';
    final statusIcon = isOver
        ? Icons.error_rounded
        : Icons.check_circle_rounded;

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
                      'The amount you can spend today while remaining '
                      'within your budget plan.',
                  howIsItCalculated:
                      'Remaining budget ÷ Remaining days\n\n'
                      'Remaining budget = Budget amount − Total spent\n'
                      'Remaining days = Budget end date − Today + 1',
                  example:
                      'Budget: ₹30,000\n'
                      'Spent: ₹9,000\n'
                      'Remaining: ₹21,000\n'
                      'Days left: 20\n\n'
                      'Safe spending: ₹21,000 ÷ 20 = ₹1,050',
                  additionalNotes:
                      '• Status shown: On Track / Near Limit / Exceeded\n'
                      '• Updates as you add or edit expenses\n'
                      '• Unused allowance carries over to the next day',
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
          Text(
            CurrencyFormatter.format(
              allowance,
              code: currency,
              decimalDigits: 0,
            ),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 12),
          AppProgress(value: dayRatio, showLabel: false),
          const SizedBox(height: 16),
          if (!isOver) ...[
            _infoRow(
              theme,
              '${CurrencyFormatter.format(allowance, code: currency, decimalDigits: 0)} safe limit',
            ),
            const SizedBox(height: 4),
            _infoRow(
              theme,
              '${CurrencyFormatter.format(spent, code: currency, decimalDigits: 0)} spent',
            ),
            const SizedBox(height: 4),
            _infoRow(
              theme,
              '${CurrencyFormatter.format(allowance - spent, code: currency, decimalDigits: 0)} remaining',
              isBold: true,
              color: statusColor,
            ),
          ] else ...[
            _infoRow(
              theme,
              '${CurrencyFormatter.format(spent, code: currency, decimalDigits: 0)} spent',
            ),
            const SizedBox(height: 4),
            _infoRow(
              theme,
              '${CurrencyFormatter.format(summary.todayOverspending, code: currency, decimalDigits: 0)} over your safe limit',
              isBold: true,
              color: statusColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme,
    String text, {
    bool isBold = false,
    Color? color,
  }) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  Color _statusColor(bool isOver) {
    return isOver ? AppColors.error : AppColors.success;
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
              InfoIcon(
                content: InfoContent(
                  title: 'Remaining Days',
                  whatIsThis:
                      'The number of calendar days remaining in your '
                      'active budget period, including today.',
                  howIsItCalculated:
                      'Remaining days = Budget end date − Today + 1\n\n'
                      'The result is always at least 1 to prevent '
                      'division errors in daily calculations.',
                  example:
                      'Budget: 10 Aug → 25 Aug\n'
                      'Today: 15 Aug\n'
                      'Remaining: 25 − 15 + 1 = 11 days',
                  additionalNotes:
                      '• Today is always counted as a remaining day\n'
                      '• The minimum value is 1 (never 0)\n'
                      '• Used by the daily safe spending calculation\n'
                      '• The budget end date determines when remaining '
                        'days reach 1',
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
