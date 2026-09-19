import '../../../../core/currency/currency_formatter.dart';
import '../../../budget/domain/entities/budget_status.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../entities/budget_daily_limit_entity.dart';
import '../entities/smart_insight_entity.dart';
import '../entities/spending_target_entity.dart';
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
  /// Optionally accepts [spendingTarget] (the active budget's daily/weekly
  /// target) and [budgetDailyLimits] for per-budget insights. Insights are
  /// ordered by severity so the most important message appears first on the
  /// Dashboard.
  List<SmartInsight> call(
    BudgetSummaryEntity summary, {
    SpendingTargetEntity? spendingTarget,
    List<BudgetDailyLimitEntity>? budgetDailyLimits,
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

    final insights = <SmartInsight>[];

    // 1. Per-budget insights (highest priority — budget-specific).
    if (budgetDailyLimits != null && budgetDailyLimits.isNotEmpty) {
      _addPerBudgetInsights(budgetDailyLimits, insights);
    }

    // 2. Critical overspending (highest priority for single-budget).
    if (insights.length < 3) {
      _addCriticalOverspending(summary, insights);
    }

    // 3. Projected overspending / budget risk.
    if (insights.length < 3) {
      _addProjectedOverspending(summary, insights);
    }

    // 4. Per-budget weekly insights.
    if (budgetDailyLimits != null &&
        budgetDailyLimits.isNotEmpty &&
        insights.length < 3) {
      _addPerBudgetWeeklyInsights(budgetDailyLimits, insights);
    }

    // 5. Per-budget progress insights.
    if (budgetDailyLimits != null &&
        budgetDailyLimits.isNotEmpty &&
        insights.length < 3) {
      _addPerBudgetProgressInsights(budgetDailyLimits, insights);
    }

    // 6. Today overspending (fallback).
    if (insights.length < 3) {
      _addTodayOverspending(summary, insights);
    }

    // 7. Spending target insights (legacy fallback).
    if (spendingTarget != null && insights.length < 3) {
      _addWeeklyTargetInsight(spendingTarget, summary.currency, insights);
    }
    if (spendingTarget != null && insights.length < 3) {
      _addDailyTargetInsight(spendingTarget, summary.currency, insights);
    }

    // 8. Spending pace relative to safe allowance.
    if (insights.length < 3) {
      _addSpendingPace(summary, insights);
    }

    // 9. Budget progress.
    if (insights.length < 3) {
      _addBudgetProgress(summary, insights);
    }

    // 10. Positive / projected savings.
    if (insights.length < 3) {
      _addPositive(summary, insights);
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

  void _addTodayOverspending(
    BudgetSummaryEntity summary,
    List<SmartInsight> insights,
  ) {
    if (summary.todayOverspending <= 0 || insights.length >= 3) return;
    insights.add(
      SmartInsight(
        id: 'today_overspending',
        message:
            "You've spent "
            '${_money(summary.todayOverspending, summary.currency)} over '
            "Today's Safe Spending in your active budget.",
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
            'At your current daily average, this budget may end its period '
            'about ${_money(summary.expectedOverspending, summary.currency)} '
            'over its amount.',
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
    final pct = (diff.abs() / safe * 100).toStringAsFixed(0);

    if (diff >= 0) {
      insights.add(
        SmartInsight(
          id: 'spending_pace_under',
          message:
              "You're averaging about "
              "${_money(diff, summary.currency)} less per day than Today's "
              'Safe Spending.',
          type: InsightType.positive,
        ),
      );
    } else {
      insights.add(
        SmartInsight(
          id: 'spending_pace_over',
          message:
              "You're averaging about "
              "${_money(diff.abs(), summary.currency)} more per day than "
              "Today's Safe Spending ($pct% over).",
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

  void _addDailyTargetInsight(
    SpendingTargetEntity target,
    String currency,
    List<SmartInsight> insights,
  ) {
    if (target.dailyTarget <= 0) return;

    if (target.dailyStatus == SpendingTargetStatus.exceeded) {
      insights.add(
        SmartInsight(
          id: 'daily_target_exceeded',
          message:
              "You've spent ${_money(target.dailyExceeded, currency)} over "
              "Today's Safe Spending.",
          type: InsightType.warning,
        ),
      );
    } else if (target.dailyStatus == SpendingTargetStatus.nearLimit) {
      final pct = (target.dailyProgress * 100).round();
      insights.add(
        SmartInsight(
          id: 'daily_target_near',
          message:
              "You're at $pct% of Today's Safe Spending "
              '(${_money(target.dailyRemaining, currency)} left today).',
          type: InsightType.warning,
        ),
      );
    } else if (target.dailyProgress > 0) {
      final pct = (target.dailyProgress * 100).round();
      insights.add(
        SmartInsight(
          id: 'daily_target_on_track',
          message:
              "You're at $pct% of Today's Safe Spending with "
              '${_money(target.dailyRemaining, currency)} left today.',
          type: InsightType.positive,
        ),
      );
    }
  }

  void _addWeeklyTargetInsight(
    SpendingTargetEntity target,
    String currency,
    List<SmartInsight> insights,
  ) {
    if (target.weeklyTarget <= 0) return;

    if (target.weeklyStatus == SpendingTargetStatus.exceeded) {
      insights.add(
        SmartInsight(
          id: 'weekly_target_exceeded',
          message:
              "This week's spending is "
              "${_money(target.weeklyExceeded, currency)} over this budget's "
              'weekly share. Spending less over the next few days helps you '
              'stay within the budget period.',
          type: InsightType.negative,
        ),
      );
    } else if (target.weeklyProgress > 0) {
      final pct = (target.weeklyProgress * 100).round();
      insights.add(
        SmartInsight(
          id: 'weekly_target_status',
          message:
              "You've used $pct% of this budget's weekly share with "
              '${_money(target.weeklyRemaining, currency)} left this week.',
          type: target.weeklyStatus == SpendingTargetStatus.nearLimit
              ? InsightType.warning
              : InsightType.positive,
        ),
      );
    }
  }

  void _addPositive(BudgetSummaryEntity summary, List<SmartInsight> insights) {
    if (summary.expectedSavings > 0) {
      insights.add(
        SmartInsight(
          id: 'on_track_savings',
          message:
              'At your current daily average, this budget should end its '
              'period with about '
              '${_money(summary.expectedSavings, summary.currency)} left.',
          type: InsightType.positive,
        ),
      );
    } else if (summary.status == BudgetStatus.underBudget) {
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
