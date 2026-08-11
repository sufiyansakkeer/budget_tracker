import '../../../../core/currency/currency_formatter.dart';
import '../../../budget/domain/entities/budget_status.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../entities/smart_insight_entity.dart';

/// Deterministic Smart Insights engine.
///
/// Translates the existing [BudgetSummaryEntity] (produced by the Budget
/// Engine) into prioritized, actionable insight messages. Insights are derived
/// exclusively from real local data — never random or generic filler.
///
/// The engine is a pure domain service: it contains no database, UI, or
/// Flutter dependencies, and is fully unit-testable.
class GetSmartInsightsUseCase {
  const GetSmartInsightsUseCase();

  /// Derives a prioritized list of [SmartInsight] messages from [summary].
  ///
  /// Insights are ordered by severity so the most important message appears
  /// first on the Dashboard.
  List<SmartInsight> call(BudgetSummaryEntity summary) {
    if (summary.monthlyAmount <= 0) {
      return const [
        SmartInsight(
          id: 'no_budget',
          message:
              'Set a budget amount to unlock spending insights for this period.',
          type: InsightType.info,
        ),
      ];
    }

    final insights = <SmartInsight>[];

    // 1. Critical overspending (highest priority).
    _addCriticalOverspending(summary, insights);

    // 2. Projected overspending / budget risk.
    _addProjectedOverspending(summary, insights);

    // 3. Today overspending.
    _addTodayOverspending(summary, insights);

    // 4. Spending pace relative to safe allowance.
    if (insights.length < 3) {
      _addSpendingPace(summary, insights);
    }

    // 5. Budget progress.
    if (insights.length < 3) {
      _addBudgetProgress(summary, insights);
    }

    // 6. Positive / projected savings.
    if (insights.length < 3) {
      _addPositive(summary, insights);
    }

    // Fallback: generic informational message using real data.
    if (insights.isEmpty) {
      insights.add(
        SmartInsight(
          id: 'general',
          message:
              'You\'ve spent '
              '${_money(summary.totalSpent, summary.currency)} of your '
              '${_money(summary.monthlyAmount, summary.currency)} budget.',
          type: InsightType.info,
        ),
      );
    }

    return insights;
  }

  void _addCriticalOverspending(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.status != BudgetStatus.overBudget) return;
    insights.add(
      SmartInsight(
        id: 'over_budget',
        message:
            'You\'ve exceeded your budget by '
            '${_money(summary.expectedOverspending, summary.currency)}. '
            'Your daily allowance has been adjusted for the remaining days.',
        type: InsightType.negative,
      ),
    );
  }

  void _addTodayOverspending(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.todayOverspending <= 0 || insights.length >= 3) return;
    insights.add(
      SmartInsight(
        id: 'today_overspending',
        message:
            'You\'ve exceeded today\'s safe spending by '
            '${_money(summary.todayOverspending, summary.currency)}.',
        type: InsightType.warning,
      ),
    );
  }

  void _addProjectedOverspending(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.expectedOverspending <= 0 || insights.length >= 3) return;
    insights.add(
      SmartInsight(
        id: 'projected_overspending',
        message:
            'At your current pace, you may exceed this budget by '
            'approximately ${_money(summary.expectedOverspending, summary.currency)}.',
        type: InsightType.warning,
      ),
    );
  }

  void _addSpendingPace(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.averageDailySpending <= 0) return;

    final safe = summary.dailySafeSpending;
    if (safe <= 0) return;

    final diff = safe - summary.averageDailySpending;
    final percent = (diff / safe * 100).abs();

    if (diff >= 0) {
      insights.add(
        SmartInsight(
          id: 'spending_pace_under',
          message:
              'You\'re spending about '
              '${_money(diff, summary.currency)} less per day than your '
              'current safe allowance.',
          type: InsightType.positive,
        ),
      );
    } else {
      insights.add(
        SmartInsight(
          id: 'spending_pace_over',
          message:
              'You\'re spending about '
              '${_money(diff.abs(), summary.currency)} more per day than '
              'your safe allowance (${percent.toStringAsFixed(0)}% over).',
          type: InsightType.warning,
        ),
      );
    }
  }

  void _addBudgetProgress(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.budgetUtilization <= 0) return;
    final usedPercent = (summary.spendingPercentage).round();
    insights.add(
      SmartInsight(
        id: 'budget_progress',
        message:
            'You\'ve used $usedPercent% of your budget and '
            'have ${summary.remainingDays} ${summary.remainingDays == 1 ? 'day' : 'days'} remaining.',
        type: usedPercent >= 80
            ? InsightType.warning
            : InsightType.info,
      ),
    );
  }

  void _addPositive(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.expectedSavings > 0) {
      insights.add(
        SmartInsight(
          id: 'on_track_savings',
          message:
              'You\'re on track to finish this budget period with '
              'approximately ${_money(summary.expectedSavings, summary.currency)} remaining.',
          type: InsightType.positive,
        ),
      );
    } else if (summary.status == BudgetStatus.underBudget) {
      insights.add(
        const SmartInsight(
          id: 'under_budget',
          message: 'You\'re within your budget. Keep it up!',
          type: InsightType.positive,
        ),
      );
    }
  }

  String _money(double amount, String currency) {
    return CurrencyFormatter.format(amount, code: currency);
  }
}
