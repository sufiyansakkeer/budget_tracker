import '../../../../core/currency/currency_formatter.dart';
import '../../../budget/domain/entities/budget_status.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../entities/budget_daily_limit_entity.dart';
import '../entities/smart_insight_entity.dart';
import '../entities/spending_target_status.dart';

/// Deterministic, rule-based Smart Insights engine (no AI, no network).
///
/// Translates the active budget's [BudgetSummaryEntity] and the per-budget
/// daily limits into prioritized, actionable insight messages. Insights are
/// derived exclusively from real local data — never random or generic filler.
/// Amounts are never combined across budgets.
///
/// The engine is a pure domain service: it contains no database, UI, or
/// Flutter dependencies, and is fully unit-testable.
class GetSmartInsightsUseCase {
  const GetSmartInsightsUseCase();

  /// Derives a prioritized list of [SmartInsight] messages from [summary].
  ///
  /// Optionally accepts [budgetDailyLimits] for per-budget insights.
  /// Insights are ordered by severity so the most important message appears
  /// first on the Dashboard.
  ///
  /// Insights need [safeToSpend], the active budget's engine result: without
  /// it there is no daily figure on Home to compare against, and the old
  /// summary-based lines (bill-blind) contradicted the hero, so none are
  /// returned. With it, the summary's forecast is replaced by ONE
  /// forecast insight from the engine, so insights never contradict Today's
  /// Safe Spending shown above them.
  List<SmartInsight> call(
    BudgetSummaryEntity summary, {
    List<BudgetDailyLimitEntity>? budgetDailyLimits,
    SafeToSpendEntity? safeToSpend,
  }) {
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

    final engine = safeToSpend;
    if (engine == null) return const [];

    final insights = <SmartInsight>[];

    // The engine result covers the active budget; its old per-budget daily
    // and weekly insights would repeat (or contradict) the hero.
    final otherLimits = budgetDailyLimits
        ?.where((bl) => bl.budgetId != engine.budgetId)
        .toList();

    // 1. Per-budget insights (highest priority — budget-specific).
    if (otherLimits != null && otherLimits.isNotEmpty) {
      _addPerBudgetInsights(otherLimits, insights);
    }

    // 2. Critical overspending (highest priority for single-budget).
    if (insights.length < 3) {
      _addCriticalOverspending(summary, insights);
    }

    // 3. Projected overspending / budget risk.
    if (insights.length < 3) {
      _addEngineForecastShort(engine, insights);
    }

    // 4. Per-budget weekly insights.
    if (otherLimits != null && otherLimits.isNotEmpty && insights.length < 3) {
      _addPerBudgetWeeklyInsights(otherLimits, insights);
    }

    // 5. Per-budget progress insights.
    if (budgetDailyLimits != null &&
        budgetDailyLimits.isNotEmpty &&
        insights.length < 3) {
      _addPerBudgetProgressInsights(budgetDailyLimits, insights);
    }

    // 6. Budget progress.
    if (insights.length < 3) {
      _addBudgetProgress(summary, insights);
    }

    // 7. Positive forecast.
    if (insights.length < 3) {
      _addEnginePositive(engine, insights);
    }

    // Fallback: generic informational message using real data.
    if (insights.isEmpty) {
      insights.add(
        SmartInsight(
          id: 'general',
          message:
              "You've spent ${_money(summary.totalSpent, summary.currency)} "
              'of your ${_money(summary.monthlyAmount, summary.currency)} budget.',
          type: InsightType.info,
        ),
      );
    }

    return insights;
  }

  // ── Per-budget insights ─────────────────────────────────────────────────

  void _addPerBudgetInsights(
    List<BudgetDailyLimitEntity> budgetLimits,
    List<SmartInsight> insights,
  ) {
    // Show over-limit budgets first.
    for (final bl in budgetLimits) {
      if (insights.length >= 3) return;
      if (bl.isOverLimit) {
        insights.add(
          SmartInsight(
            id: 'per_budget_over_${bl.budgetId}',
            message:
                "${bl.budgetName}: you've spent "
                "${_money(bl.exceededToday, bl.currency)} over Today's Safe "
                'Spending.',
            type: InsightType.negative,
          ),
        );
      }
    }

    // Then show near-limit budgets.
    for (final bl in budgetLimits) {
      if (insights.length >= 3) return;
      if (bl.status == SpendingTargetStatus.nearLimit) {
        final pct = (bl.progress * 100).round();
        insights.add(
          SmartInsight(
            id: 'per_budget_near_${bl.budgetId}',
            message:
                "${bl.budgetName} is at $pct% of Today's Safe Spending "
                '(${_money(bl.remainingToday, bl.currency)} left today).',
            type: InsightType.warning,
          ),
        );
      }
    }
  }

  void _addPerBudgetWeeklyInsights(
    List<BudgetDailyLimitEntity> budgetLimits,
    List<SmartInsight> insights,
  ) {
    for (final bl in budgetLimits) {
      if (insights.length >= 3) return;
      if (bl.weeklyStatus == SpendingTargetStatus.exceeded) {
        insights.add(
          SmartInsight(
            id: 'per_budget_weekly_over_${bl.budgetId}',
            message:
                "${bl.budgetName}: this week's spending is "
                '${_money(bl.weeklyExceeded, bl.currency)} over its weekly '
                'share of the budget.',
            type: InsightType.warning,
          ),
        );
      }
    }
  }

  void _addPerBudgetProgressInsights(
    List<BudgetDailyLimitEntity> budgetLimits,
    List<SmartInsight> insights,
  ) {
    for (final bl in budgetLimits) {
      if (insights.length >= 3) return;
      if (bl.budgetUtilization > 0 && bl.budgetUtilization < 1.0) {
        final usedPercent = (bl.budgetUtilization * 100).round();
        final dayLabel = bl.remainingDays == 1 ? 'day' : 'days';
        insights.add(
          SmartInsight(
            id: 'per_budget_progress_${bl.budgetId}',
            message:
                '${bl.budgetName} has used $usedPercent% of its '
                '${_money(bl.monthlyAmount, bl.currency)} budget '
                'with ${bl.remainingDays} $dayLabel remaining.',
            type: usedPercent >= 80
                ? InsightType.warning
                : InsightType.positive,
          ),
        );
        return; // Only show one progress insight
      }
    }
  }

  // ── Legacy insights ──────────────────────────────────────────────────────

  void _addCriticalOverspending(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.status != BudgetStatus.overBudget) return;
    final overspent = summary.totalSpent - summary.monthlyAmount;
    insights.add(
      SmartInsight(
        id: 'over_budget',
        message:
            "You've spent ${_money(overspent, summary.currency)} more than "
            "this budget's total amount. There is no safe amount left to "
            'spend for the rest of this period.',
        type: InsightType.negative,
      ),
    );
  }

  void _addBudgetProgress(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.budgetUtilization <= 0) return;
    final usedPercent = summary.spendingPercentage.round();
    insights.add(
      SmartInsight(
        id: 'budget_progress',
        message:
            "You've used $usedPercent% of this budget with "
            '${summary.remainingDays} '
            '${summary.remainingDays == 1 ? 'day' : 'days'} left in its '
            'period.',
        type: usedPercent >= 80 ? InsightType.warning : InsightType.info,
      ),
    );
  }

  // ── Safe-to-spend engine insights ───────────────────────────────────────

  /// Projected shortfall: at the recent pace, spending would eat into the
  /// money protected for bills, kept aside or the savings goal (or past the
  /// budget when nothing is protected).
  void _addEngineForecastShort(
    SafeToSpendEntity engine,
    List<SmartInsight> insights,
  ) {
    final forecast = engine.forecast;
    if (forecast == null || !forecast.isReliable) return;
    final margin = forecast.projectedMargin!;
    if (margin >= 0) return;
    final protects = engine.totalDeductions > 0;
    insights.add(
      SmartInsight(
        id: 'safe_spend_forecast_short',
        message:
            'At your recent pace of about '
            '${_money(forecast.averageDaily!, engine.currency)} a day, this '
            'budget may end its period '
            '${_money(-margin, engine.currency)} short'
            '${protects ? ' of what it needs for bills and money set aside' : ''}'
            '.',
        type: InsightType.warning,
      ),
    );
  }

  /// Positive forecast, or a plain "within budget" when there is no
  /// forecast yet and nothing needs attention.
  void _addEnginePositive(
    SafeToSpendEntity engine,
    List<SmartInsight> insights,
  ) {
    final forecast = engine.forecast;
    if (forecast != null && forecast.isReliable) {
      final margin = forecast.projectedMargin!;
      if (margin < 0) return;
      final protects = engine.totalDeductions > 0;
      insights.add(
        SmartInsight(
          id: 'safe_spend_forecast_ok',
          message:
              'At your recent pace of about '
              '${_money(forecast.averageDaily!, engine.currency)} a day, this '
              'budget should end its period with about '
              '${_money(margin, engine.currency)} free to spend'
              '${protects ? ' after bills and money set aside' : ''}'
              '.',
          type: InsightType.positive,
        ),
      );
    } else if (engine.status == SafeToSpendStatus.onTrack) {
      insights.add(
        const SmartInsight(
          id: 'under_budget',
          message: "You're within this budget. Keep it up!",
          type: InsightType.positive,
        ),
      );
    }
  }

  String _money(double amount, String currency) {
    return CurrencyFormatter.format(amount, code: currency);
  }
}
