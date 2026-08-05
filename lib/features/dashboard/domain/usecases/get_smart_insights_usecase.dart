import '../../../budget/domain/entities/budget_status.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../entities/smart_insight_entity.dart';

/// Generates user-facing insight messages from a [BudgetSummaryEntity].
///
/// The summary is produced by the existing Budget Engine, so this use case
/// contains no calculation logic — it only translates engine results into
/// human-readable messages. The Dashboard displays these insights as-is.
class GetSmartInsightsUseCase {
  const GetSmartInsightsUseCase();

  /// Derives a list of [SmartInsight] messages from [summary].
  List<SmartInsight> call(BudgetSummaryEntity summary) {
    final insights = <SmartInsight>[];

    _addBudgetStatusInsight(summary, insights);
    _addTodayOverspendingInsight(summary, insights);
    _addSpendingPaceInsight(summary, insights);

    if (insights.isEmpty) {
      insights.add(
        const SmartInsight(
          id: 'on_track',
          message: 'Your spending is on track. Keep it up!',
          type: InsightType.info,
        ),
      );
    }

    return insights;
  }

  void _addBudgetStatusInsight(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    switch (summary.status) {
      case BudgetStatus.underBudget:
        if (summary.expectedSavings > 0) {
          insights.add(
            SmartInsight(
              id: 'on_track_savings',
              message:
                  'Great! You\'re on track to save '
                  '${_money(summary.expectedSavings, summary.currency)}.',
              type: InsightType.positive,
            ),
          );
        } else {
          insights.add(
            const SmartInsight(
              id: 'under_budget',
              message: 'You\'re within your budget. Keep it up!',
              type: InsightType.positive,
            ),
          );
        }
        break;
      case BudgetStatus.nearLimit:
        insights.add(
          SmartInsight(
            id: 'near_limit',
            message:
                'You\'re approaching your budget limit. '
                'Consider reducing spending.',
            type: InsightType.warning,
          ),
        );
        break;
      case BudgetStatus.overBudget:
        insights.add(
          SmartInsight(
            id: 'over_budget',
            message:
                'You\'ve exceeded your budget by '
                '${_money(summary.expectedOverspending, summary.currency)}.',
            type: InsightType.negative,
          ),
        );
        break;
    }
  }

  void _addTodayOverspendingInsight(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.todayOverspending > 0) {
      insights.add(
        SmartInsight(
          id: 'today_overspending',
          message:
              'You overspent by '
              '${_money(summary.todayOverspending, summary.currency)} today.',
          type: InsightType.warning,
        ),
      );
    }
  }

  void _addSpendingPaceInsight(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.expectedOverspending > 0) {
      insights.add(
        SmartInsight(
          id: 'projected_overspending',
          message:
              'You\'re likely to exceed your budget by '
              '${_money(summary.expectedOverspending, summary.currency)}.',
          type: InsightType.negative,
        ),
      );
    }
  }

  String _money(double amount, String currency) {
    final isZero = amount.abs() < 0.005;
    final formatted = amount.toStringAsFixed(isZero ? 0 : 0);
    return isZero ? formatted : '$currency$formatted';
  }
}
