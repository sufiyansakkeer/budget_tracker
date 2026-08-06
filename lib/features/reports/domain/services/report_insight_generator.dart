import 'package:intl/intl.dart';

import '../../../dashboard/domain/entities/smart_insight_entity.dart';
import '../entities/report_data.dart';

/// Generates data-driven, human-readable [SmartInsight] messages from a
/// computed [ReportData]. Contains no calculation logic — it only translates
/// analytics results into user-facing copy.
class ReportInsightGenerator {
  const ReportInsightGenerator();

  /// Builds a list of insights from [data], ordered by importance.
  List<SmartInsight> generate(ReportData data) {
    if (data.isEmpty) {
      return const [
        SmartInsight(
          id: 'no_data',
          message: 'Add expenses to see personalized insights.',
          type: InsightType.info,
        ),
      ];
    }

    final insights = <SmartInsight>[];
    _addSpendingComparisonInsight(data, insights);
    _addTopCategoryInsight(data, insights);
    _addHighestSpendingDayInsight(data, insights);
    _addWeekendInsight(data, insights);
    _addProjectionInsight(data, insights);
    _addTrendInsight(data, insights);
    _addConsistencyInsight(data, insights);

    if (insights.isEmpty) {
      insights.add(
        SmartInsight(
          id: 'overview',
          message:
              'You spent ${_money(data.overview.totalSpending, data)} across '
              '${data.overview.totalTransactions} transactions.',
          type: InsightType.info,
        ),
      );
    }

    return insights;
  }

  void _addSpendingComparisonInsight(
    ReportData data,
    List<SmartInsight> insights,
  ) {
    final change = data.trend.growthRate;
    if (change.abs() < 0.02) return;
    final decreased = change < 0;
    insights.add(
      SmartInsight(
        id: decreased ? 'spending_decreased' : 'spending_increased',
        message: decreased
            ? 'You\'re spending ${(change.abs() * 100).toStringAsFixed(0)}% less '
                  'than the previous period. Great job!'
            : 'You\'re spending ${(change.abs() * 100).toStringAsFixed(0)}% more '
                  'than the previous period.',
        type: decreased ? InsightType.positive : InsightType.warning,
      ),
    );
  }

  void _addTopCategoryInsight(ReportData data, List<SmartInsight> insights) {
    if (data.categoryAnalytics.isEmpty) return;
    final top = data.categoryAnalytics.first;
    insights.add(
      SmartInsight(
        id: 'top_category',
        message:
            '${top.categoryName} accounts for '
            '${top.percentageOfTotal.toStringAsFixed(0)}% of your spending.',
        type: InsightType.info,
      ),
    );
  }

  void _addHighestSpendingDayInsight(
    ReportData data,
    List<SmartInsight> insights,
  ) {
    final day = data.timeAnalytics.highestSpendingWeekday;
    if (day == null) return;
    final names = _weekdayNames();
    insights.add(
      SmartInsight(
        id: 'highest_spending_day',
        message: 'Your highest spending day is ${names[day - 1]}.',
        type: InsightType.info,
      ),
    );
  }

  void _addWeekendInsight(ReportData data, List<SmartInsight> insights) {
    final time = data.timeAnalytics;
    final total = time.weekdaySpending + time.weekendSpending;
    if (total <= 0) return;
    final weekendRatio = time.weekendSpending / total;
    if (weekendRatio > 0.45) {
      insights.add(
        const SmartInsight(
          id: 'weekend_spending',
          message: 'You usually spend more during weekends.',
          type: InsightType.warning,
        ),
      );
    }
  }

  void _addProjectionInsight(ReportData data, List<SmartInsight> insights) {
    if (data.currentBudget == null || data.currentMonthBudget <= 0) return;
    final spent = data.currentMonthSpent;
    final budget = data.currentMonthBudget;
    if (spent < budget) {
      final projectedSavings = budget - spent;
      insights.add(
        SmartInsight(
          id: 'projected_savings',
          message:
              'You are likely to save ${_money(projectedSavings, data)} '
              'this month.',
          type: InsightType.positive,
        ),
      );
    } else {
      final overspent = spent - budget;
      insights.add(
        SmartInsight(
          id: 'budget_exceeded',
          message:
              'You\'ve exceeded your monthly budget by '
              '${_money(overspent, data)}.',
          type: InsightType.negative,
        ),
      );
    }
  }

  void _addTrendInsight(ReportData data, List<SmartInsight> insights) {
    if (data.trend.isImproving) {
      insights.add(
        const SmartInsight(
          id: 'trend_improving',
          message: 'Your spending trend has improved over the last two weeks.',
          type: InsightType.positive,
        ),
      );
    }
  }

  void _addConsistencyInsight(ReportData data, List<SmartInsight> insights) {
    if (data.trend.consistencyScore >= 0.7 && data.trend.dailyAverage > 0) {
      insights.add(
        const SmartInsight(
          id: 'consistent_spending',
          message: 'Your daily spending is very consistent.',
          type: InsightType.info,
        ),
      );
    }
  }

  String _money(double amount, ReportData data) {
    final currency = data.currentBudget?.currency ?? '₹';
    return NumberFormat.currency(
      symbol: currency,
      decimalDigits: 0,
    ).format(amount);
  }

  List<String> _weekdayNames() {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
  }
}
