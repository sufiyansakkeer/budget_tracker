import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import 'category_analytics.dart';
import 'category_slice.dart';
import 'daily_spending_point.dart';
import 'monthly_spending_bucket.dart';
import 'report_overview.dart';
import 'report_period.dart';
import 'spending_trend.dart';
import 'time_analytics.dart';
import 'weekly_comparison.dart';

/// Complete snapshot of computed report data for one [ReportRange].
///
/// Business logic never lives in the UI; this is produced by the
/// AnalyticsService and consumed by the reports screen.
class ReportData extends Equatable {
  final ReportRange range;

  /// The filtered expenses used to compute all analytics below.
  final List<ExpenseEntity> filteredExpenses;

  /// Categories used to resolve names/colors.
  final List<ExpenseCategory> categories;

  /// Active report filter (category, date range, amount, tags, receipt).
  final ExpenseHistoryFilter filter;

  final ReportOverview overview;

  /// Daily spending line chart data.
  final List<DailySpendingPoint> dailySpending;

  /// Weekly (month view) or monthly (year view) bar chart buckets.
  final List<SpendingBucket> spendingBuckets;

  /// Category distribution for the pie chart.
  final List<CategorySlice> categorySlices;

  /// Ordered (highest first) category analytics.
  final List<CategoryAnalytics> categoryAnalytics;

  final TimeAnalytics timeAnalytics;
  final SpendingTrend trend;
  final WeeklyComparison? weeklyComparison;

  /// Current month Budget snapshot used for budget cards. Null when the
  /// selected range does not cover the current month.
  final BudgetEntity? currentBudget;
  final double currentMonthSpent;
  final double currentMonthBudget;

  const ReportData({
    required this.range,
    required this.filteredExpenses,
    required this.categories,
    required this.filter,
    required this.overview,
    required this.dailySpending,
    required this.spendingBuckets,
    required this.categorySlices,
    required this.categoryAnalytics,
    required this.timeAnalytics,
    required this.trend,
    this.weeklyComparison,
    this.currentBudget,
    this.currentMonthSpent = 0,
    this.currentMonthBudget = 0,
  });

  bool get isEmpty => filteredExpenses.isEmpty;

  @override
  List<Object?> get props => [
    range,
    filteredExpenses,
    categories,
    filter,
    overview,
    dailySpending,
    spendingBuckets,
    categorySlices,
    categoryAnalytics,
    timeAnalytics,
    trend,
    weeklyComparison,
    currentBudget,
    currentMonthSpent,
    currentMonthBudget,
  ];
}
