import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'safe_to_spend_breakdown_card.dart';
import 'safe_to_spend_copy.dart';

/// "Free to spend until 31 Oct · ₹20,253", with one line naming what was
/// set aside. One tap opens the full working ([SafeToSpendWorkingSheet]).
///
/// This is the progressive-disclosure step between the hero's figure and
/// the ledger: the result first, the reasoning on request.
class FreeToSpendSummary extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;
  final VoidCallback onTap;

  const FreeToSpendSummary({
    super.key,
    required this.safeToSpend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = safeToSpend;
    final value = SafeToSpendCopy.freeToSpendValue(e);
    final detail = SafeToSpendCopy.freeToSpendContext(e);
    return AppSurface(
      level: SurfaceLevel.sunken,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.smd,
        AppSpacing.sm,
        AppSpacing.smd,
      ),
      onTap: onTap,
      semanticLabel:
          'Free to spend until ${SafeToSpendCopy.spokenDate(e.endDate)}, '
          '$value. $detail. Shows how today\'s amount is worked out',
      // The figure hugs the chevron at the right edge and may take up to
      // 45% of the row before it scales down; the label wraps in the rest.
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Free to spend', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.45,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  value,
                  style: context.appTypography.moneyTitle.copyWith(
                    color: e.shortfall > 0
                        ? context.tone(AppTone.critical).accent
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

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
        const AppSheetHeader(
          title: "How today's amount is worked out",
          subtitle:
              'Fixed for today. Tomorrow it is worked out again from what '
              'is left, so spending less today raises it.',
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
