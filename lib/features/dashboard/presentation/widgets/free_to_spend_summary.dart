import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'safe_to_spend_breakdown_card.dart';
import 'safe_to_spend_copy.dart';
import 'target_trend.dart';
import '../../domain/usecases/get_day_targets_usecase.dart';
import '../../../budget/domain/entities/safe_to_spend/day_target.dart';
import '../../../../core/di/injection.dart';

/// The full working of today's amount, laid out like a receipt: the
/// breakdown down to "Free to spend", then today's spending added back and
/// the division by the days left, ending at today's amount; then what
/// tomorrow looks like and the forecast.
abstract final class SafeToSpendWorkingSheet {
  static Future<void> show(BuildContext context, SafeToSpendEntity e) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) => _WorkingSheet(entity: e),
    );
  }
}

class _WorkingSheet extends StatelessWidget {
  final SafeToSpendEntity entity;

  const _WorkingSheet({required this.entity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entity;
    final tomorrow = SafeToSpendCopy.tomorrowPreview(e);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetHeader(
          title:
              'Why ${SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency)}?',
          subtitle:
              "Spend less than the target and tomorrow's rises; spend more "
              'and it falls; spend exactly the target and it stays the same.',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeToSpendBreakdownCard(
                  safeToSpend: e,
                  afterFreeToSpend: e.isRunning ? _TodayRows(entity: e) : null,
                ),
                if (e.isRunning &&
                    getIt.isRegistered<GetDayTargetsUseCase>()) ...[
                  // Blueprint: how the target has moved, after the sum.
                  FutureBuilder<Map<DateTime, DayTarget>>(
                    future: getIt<GetDayTargetsUseCase>()(
                      e.budgetId,
                    ).catchError((Object _) => <DateTime, DayTarget>{}),
                    builder: (context, snapshot) {
                      final days = snapshot.data?.values.toList() ?? const [];
                      if (days.length < 2) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: TargetTrend(days: days, currency: e.currency),
                      );
                    },
                  ),
                ],
                if (tomorrow != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.wb_twilight_rounded,
                            size: AppSizes.iconMd,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.smd),
                          Expanded(
                            child: Text(
                              tomorrow,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "+ Spent today, not counting bills · ÷ Days left · = Today's Safe
/// Spending": the last three lines of the working, from the engine's
/// figures.
class _TodayRows extends StatelessWidget {
  final SafeToSpendEntity entity;

  const _TodayRows({required this.entity});

  @override
  Widget build(BuildContext context) {
    final e = entity;
    final spent = SafeToSpendCopy.amount(e.todayDiscretionary, e.currency);
    final daily = SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BreakdownRow(
          operator: '+',
          label: 'Spent today, not counting bills',
          value: spent,
          semanticsLabel: 'Plus spent today, not counting bills, $spent',
        ),
        BreakdownRow(
          operator: '÷',
          label: 'Days left, including today',
          value: '${e.remainingDays}',
          semanticsLabel:
              'Divided by days left, including today, ${e.remainingDays}',
        ),
        Divider(
          height: AppSpacing.md,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        BreakdownRow(
          operator: '=',
          label: "Today's Safe Spending",
          value: daily,
          emphasized: true,
          semanticsLabel: "Today's Safe Spending, $daily",
        ),
      ],
    );
  }
}
