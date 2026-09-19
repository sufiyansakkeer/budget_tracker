import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';

import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';

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
                  title: 'Budget Period',
                  whatIsThis:
                      'The start and end dates of your active budget, '
                      'where today falls within them, and how many days '
                      'are left. You choose both dates when you create a '
                      'budget; a period can be any length.',
                  howIsItCalculated:
                      'Remaining days = days from today to the end date, '
                      'counting today.\n\n'
                      'The result is never below 1, so Today\'s Safe '
                      'Spending can always be calculated.',
                  example:
                      'Budget period: 10 Aug → 25 Aug\n'
                      'Today: 15 Aug\n'
                      'Remaining days: 11 (15 Aug to 25 Aug)',
                  additionalNotes:
                      '• Shows the active budget only; other budgets have '
                      'their own periods\n'
                      '• Remaining days divide the Remaining Budget to give '
                      'Today\'s Safe Spending\n'
                      '• When the period ends, create a new budget or '
                      'switch to another one',
                ),
              ),
              Text(
                '$daysRemaining days remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.appColors.secondary,
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
                        gradient: LinearGradient(
                          colors: [
                            context.appColors.secondaryDark,
                            context.appColors.secondary,
                          ],
                        ),
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
                color: context.appColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Today',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.appColors.secondary,
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
