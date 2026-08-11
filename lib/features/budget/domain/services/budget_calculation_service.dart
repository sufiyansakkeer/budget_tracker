import '../entities/budget_analytics_entity.dart';
import '../entities/budget_calculation_input.dart';
import '../entities/budget_status.dart';
import '../entities/budget_summary_entity.dart';
import '../entities/budget_thresholds.dart';

/// Pure calculation engine for all budget-related metrics.
///
/// Contains no database, UI, or Flutter dependencies.
/// All methods are deterministic and unit-testable.
class BudgetCalculationService {
  BudgetCalculationInput? _cachedInput;
  BudgetSummaryEntity? _cachedSummary;
  BudgetAnalyticsEntity? _cachedAnalytics;

  /// Clears memoized calculation results.
  void clearCache() {
    _cachedInput = null;
    _cachedSummary = null;
    _cachedAnalytics = null;
  }

  /// Returns the total number of days in the budget period (inclusive).
  int daysInPeriod({required DateTime startDate, required DateTime endDate}) {
    _validateDateRange(startDate, endDate);
    return endDate.difference(startDate).inDays + 1;
  }

  /// Days elapsed in the budget period including [referenceDate].
  ///
  /// Example: budget 10 Aug → 25 Aug, reference date 15 Aug → 6 days passed.
  int calculateDaysPassed({
    required DateTime referenceDate,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    _validateReferenceDate(referenceDate, startDate, endDate);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final ref = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final diff = ref.difference(start).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  /// Remaining days in the budget period including today.
  ///
  /// Always returns at least 1 to prevent division by zero.
  /// Example: budget 10 Aug → 25 Aug, reference date 15 Aug → 11 remaining days.
  int calculateRemainingDays({
    required DateTime referenceDate,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    _validateReferenceDate(referenceDate, startDate, endDate);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final ref = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final remaining = end.difference(ref).inDays + 1;
    return remaining < 1 ? 1 : remaining;
  }

  /// Remaining budget after subtracting total spending.
  double calculateRemainingBudget({
    required double monthlyAmount,
    required double totalSpent,
  }) {
    return monthlyAmount - totalSpent;
  }

  /// Daily safe spending allowance.
  ///
  /// Formula: remainingBudget ÷ remainingDays
  double calculateDailyAllowance({
    required double remainingBudget,
    required int remainingDays,
  }) {
    final safeDays = remainingDays < 1 ? 1 : remainingDays;
    return remainingBudget / safeDays;
  }

  /// Budget utilization as a ratio (0.0–1.0+).
  double calculateBudgetUtilization({
    required double totalSpent,
    required double monthlyAmount,
  }) {
    if (monthlyAmount <= 0) return 0;
    return totalSpent / monthlyAmount;
  }

  /// Percentage of the monthly budget that has been spent.
  double calculateSpendingPercentage({
    required double totalSpent,
    required double monthlyAmount,
  }) {
    if (monthlyAmount <= 0) return 0;
    return (totalSpent / monthlyAmount) * 100;
  }

  /// Percentage of the monthly budget still remaining.
  double calculateRemainingPercentage({
    required double remainingBudget,
    required double monthlyAmount,
  }) {
    if (monthlyAmount <= 0) return 0;
    return (remainingBudget / monthlyAmount) * 100;
  }

  /// Average daily spending based on days passed in the month.
  double calculateAverageDailySpending({
    required double totalSpent,
    required int daysPassed,
  }) {
    final safeDays = daysPassed < 1 ? 1 : daysPassed;
    return totalSpent / safeDays;
  }

  /// Projected total spending at budget-period end based on current daily average.
  double calculateExpectedPeriodEndSpending({
    required double averageDailySpending,
    required int daysInPeriod,
  }) {
    return averageDailySpending * daysInPeriod;
  }

  /// Projected savings when period-end spending stays under budget.
  ///
  /// Returns 0 when projected spending meets or exceeds the budget.
  double calculateProjectedSavings({
    required double monthlyAmount,
    required double expectedPeriodEndSpending,
  }) {
    if (expectedPeriodEndSpending >= monthlyAmount) return 0;
    return monthlyAmount - expectedPeriodEndSpending;
  }

  /// Projected overspending when period-end spending exceeds budget.
  ///
  /// Returns 0 when projected spending stays within budget.
  double calculateProjectedOverspending({
    required double monthlyAmount,
    required double expectedPeriodEndSpending,
  }) {
    if (expectedPeriodEndSpending <= monthlyAmount) return 0;
    return expectedPeriodEndSpending - monthlyAmount;
  }

  /// Amount spent over today's daily allowance.
  double calculateTodayOverspending({
    required double todaySpending,
    required double dailyAllowance,
  }) {
    final overspent = todaySpending - dailyAllowance;
    return overspent > 0 ? overspent : 0;
  }

  /// Classifies budget health using configurable [thresholds].
  BudgetStatus calculateBudgetStatus({
    required double budgetUtilization,
    BudgetThresholds thresholds = const BudgetThresholds(),
  }) {
    if (budgetUtilization > thresholds.overBudgetThreshold) {
      return BudgetStatus.overBudget;
    }
    if (budgetUtilization >= thresholds.nearLimitThreshold) {
      return BudgetStatus.nearLimit;
    }
    return BudgetStatus.underBudget;
  }

  /// Builds a complete [BudgetSummaryEntity] from raw input data.
  BudgetSummaryEntity buildSummary(
    BudgetCalculationInput input, {
    required String currency,
  }) {
    if (_cachedInput == input && _cachedSummary != null) {
      return _cachedSummary!;
    }

    final remainingBudget = calculateRemainingBudget(
      monthlyAmount: input.monthlyAmount,
      totalSpent: input.totalSpent,
    );
    final daysPassed = calculateDaysPassed(
      referenceDate: input.referenceDate,
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final remainingDays = calculateRemainingDays(
      referenceDate: input.referenceDate,
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final dailySafeSpending = calculateDailyAllowance(
      remainingBudget: remainingBudget + input.todaySpending,
      remainingDays: remainingDays,
    );
    final utilization = calculateBudgetUtilization(
      totalSpent: input.totalSpent,
      monthlyAmount: input.monthlyAmount,
    );
    final spendingPercentage = calculateSpendingPercentage(
      totalSpent: input.totalSpent,
      monthlyAmount: input.monthlyAmount,
    );
    final remainingPercentage = calculateRemainingPercentage(
      remainingBudget: remainingBudget,
      monthlyAmount: input.monthlyAmount,
    );
    final averageDailySpending = calculateAverageDailySpending(
      totalSpent: input.totalSpent,
      daysPassed: daysPassed,
    );
    final periodDays = daysInPeriod(
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final expectedPeriodEndSpending = calculateExpectedPeriodEndSpending(
      averageDailySpending: averageDailySpending,
      daysInPeriod: periodDays,
    );
    final expectedSavings = calculateProjectedSavings(
      monthlyAmount: input.monthlyAmount,
      expectedPeriodEndSpending: expectedPeriodEndSpending,
    );
    final expectedOverspending = calculateProjectedOverspending(
      monthlyAmount: input.monthlyAmount,
      expectedPeriodEndSpending: expectedPeriodEndSpending,
    );
    final todayOverspending = calculateTodayOverspending(
      todaySpending: input.todaySpending,
      dailyAllowance: dailySafeSpending,
    );
    final status = calculateBudgetStatus(
      budgetUtilization: utilization,
      thresholds: input.thresholds,
    );

    final summary = BudgetSummaryEntity(
      monthlyAmount: input.monthlyAmount,
      remainingBudget: remainingBudget,
      totalSpent: input.totalSpent,
      todaySpending: input.todaySpending,
      remainingDays: remainingDays,
      daysPassed: daysPassed,
      dailySafeSpending: dailySafeSpending,
      budgetUtilization: utilization,
      spendingPercentage: spendingPercentage,
      remainingPercentage: remainingPercentage,
      averageDailySpending: averageDailySpending,
      expectedPeriodEndSpending: expectedPeriodEndSpending,
      expectedSavings: expectedSavings,
      expectedOverspending: expectedOverspending,
      todayOverspending: todayOverspending,
      status: status,
      currency: currency,
      startDate: input.startDate,
      endDate: input.endDate,
    );

    _cachedInput = input;
    _cachedSummary = summary;
    return summary;
  }

  /// Builds extended [BudgetAnalyticsEntity] from raw input data.
  BudgetAnalyticsEntity buildAnalytics(BudgetCalculationInput input) {
    if (_cachedInput == input && _cachedAnalytics != null) {
      return _cachedAnalytics!;
    }

    final remainingBudget = calculateRemainingBudget(
      monthlyAmount: input.monthlyAmount,
      totalSpent: input.totalSpent,
    );
    final daysPassed = calculateDaysPassed(
      referenceDate: input.referenceDate,
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final daysRemaining = calculateRemainingDays(
      referenceDate: input.referenceDate,
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final dailySafeSpending = calculateDailyAllowance(
      remainingBudget: remainingBudget + input.todaySpending,
      remainingDays: daysRemaining,
    );
    final spendingPercentage = calculateSpendingPercentage(
      totalSpent: input.totalSpent,
      monthlyAmount: input.monthlyAmount,
    );
    final remainingPercentage = calculateRemainingPercentage(
      remainingBudget: remainingBudget,
      monthlyAmount: input.monthlyAmount,
    );
    final averageDailySpending = calculateAverageDailySpending(
      totalSpent: input.totalSpent,
      daysPassed: daysPassed,
    );
    final periodDays = daysInPeriod(
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final expectedPeriodEndSpending = calculateExpectedPeriodEndSpending(
      averageDailySpending: averageDailySpending,
      daysInPeriod: periodDays,
    );
    final projectedRemainingBalance =
        input.monthlyAmount - expectedPeriodEndSpending;
    final projectedSavings = calculateProjectedSavings(
      monthlyAmount: input.monthlyAmount,
      expectedPeriodEndSpending: expectedPeriodEndSpending,
    );
    final projectedOverspending = calculateProjectedOverspending(
      monthlyAmount: input.monthlyAmount,
      expectedPeriodEndSpending: expectedPeriodEndSpending,
    );
    final utilization = calculateBudgetUtilization(
      totalSpent: input.totalSpent,
      monthlyAmount: input.monthlyAmount,
    );
    final status = calculateBudgetStatus(
      budgetUtilization: utilization,
      thresholds: input.thresholds,
    );

    final analytics = BudgetAnalyticsEntity(
      monthlyAmount: input.monthlyAmount,
      totalSpent: input.totalSpent,
      remainingBudget: remainingBudget,
      spendingPercentage: spendingPercentage,
      remainingPercentage: remainingPercentage,
      averageDailySpending: averageDailySpending,
      expectedMonthEndSpending: expectedPeriodEndSpending,
      projectedRemainingBalance: projectedRemainingBalance,
      projectedSavings: projectedSavings,
      projectedOverspending: projectedOverspending,
      daysPassed: daysPassed,
      daysRemaining: daysRemaining,
      dailySafeSpending: dailySafeSpending,
      status: status,
    );

    _cachedInput = input;
    _cachedAnalytics = analytics;
    return analytics;
  }

  void _validateDateRange(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) {
      throw ArgumentError(
        'End date ${endDate.toIso8601String()} '
        'must be on or after start date ${startDate.toIso8601String()}',
      );
    }
  }

  void _validateReferenceDate(
    DateTime referenceDate,
    DateTime startDate,
    DateTime endDate,
  ) {
    _validateDateRange(startDate, endDate);
    final ref = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (ref.isBefore(start) || ref.isAfter(end)) {
      throw ArgumentError(
        'Reference date ${referenceDate.toIso8601String()} '
        'does not fall within budget period '
        '${startDate.toIso8601String()} – ${endDate.toIso8601String()}',
      );
    }
  }
}
