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

  /// Returns the number of days in [month] for [year], accounting for leap years.
  int daysInMonth(int month, int year) {
    _validateMonthYear(month, year);
    return DateTime(year, month + 1, 0).day;
  }

  /// Days elapsed in the budget month including [referenceDate].
  ///
  /// Example: reference date 10 August → 10 days passed.
  int calculateDaysPassed({
    required DateTime referenceDate,
    required int budgetMonth,
    required int budgetYear,
  }) {
    _validateReferenceDate(referenceDate, budgetMonth, budgetYear);
    return referenceDate.day;
  }

  /// Remaining days in the budget month including today.
  ///
  /// Always returns at least 1 to prevent division by zero.
  /// Example: 10 August in a 31-day month → 22 remaining days.
  int calculateRemainingDays({
    required DateTime referenceDate,
    required int budgetMonth,
    required int budgetYear,
  }) {
    _validateReferenceDate(referenceDate, budgetMonth, budgetYear);
    final totalDays = daysInMonth(budgetMonth, budgetYear);
    final remaining = totalDays - referenceDate.day + 1;
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

  /// Projected total spending at month-end based on current daily average.
  double calculateExpectedMonthEndSpending({
    required double averageDailySpending,
    required int daysInMonth,
  }) {
    return averageDailySpending * daysInMonth;
  }

  /// Projected savings when month-end spending stays under budget.
  ///
  /// Returns 0 when projected spending meets or exceeds the budget.
  double calculateProjectedSavings({
    required double monthlyAmount,
    required double expectedMonthEndSpending,
  }) {
    if (expectedMonthEndSpending >= monthlyAmount) return 0;
    return monthlyAmount - expectedMonthEndSpending;
  }

  /// Projected overspending when month-end spending exceeds budget.
  ///
  /// Returns 0 when projected spending stays within budget.
  double calculateProjectedOverspending({
    required double monthlyAmount,
    required double expectedMonthEndSpending,
  }) {
    if (expectedMonthEndSpending <= monthlyAmount) return 0;
    return expectedMonthEndSpending - monthlyAmount;
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
      budgetMonth: input.budgetMonth,
      budgetYear: input.budgetYear,
    );
    final remainingDays = calculateRemainingDays(
      referenceDate: input.referenceDate,
      budgetMonth: input.budgetMonth,
      budgetYear: input.budgetYear,
    );
    final dailySafeSpending = calculateDailyAllowance(
      remainingBudget: remainingBudget,
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
    final monthDays = daysInMonth(input.budgetMonth, input.budgetYear);
    final expectedMonthEndSpending = calculateExpectedMonthEndSpending(
      averageDailySpending: averageDailySpending,
      daysInMonth: monthDays,
    );
    final expectedSavings = calculateProjectedSavings(
      monthlyAmount: input.monthlyAmount,
      expectedMonthEndSpending: expectedMonthEndSpending,
    );
    final expectedOverspending = calculateProjectedOverspending(
      monthlyAmount: input.monthlyAmount,
      expectedMonthEndSpending: expectedMonthEndSpending,
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
      expectedMonthEndSpending: expectedMonthEndSpending,
      expectedSavings: expectedSavings,
      expectedOverspending: expectedOverspending,
      todayOverspending: todayOverspending,
      status: status,
      currency: currency,
      budgetMonth: input.budgetMonth,
      budgetYear: input.budgetYear,
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
      budgetMonth: input.budgetMonth,
      budgetYear: input.budgetYear,
    );
    final daysRemaining = calculateRemainingDays(
      referenceDate: input.referenceDate,
      budgetMonth: input.budgetMonth,
      budgetYear: input.budgetYear,
    );
    final dailySafeSpending = calculateDailyAllowance(
      remainingBudget: remainingBudget,
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
    final monthDays = daysInMonth(input.budgetMonth, input.budgetYear);
    final expectedMonthEndSpending = calculateExpectedMonthEndSpending(
      averageDailySpending: averageDailySpending,
      daysInMonth: monthDays,
    );
    final projectedRemainingBalance = input.monthlyAmount - expectedMonthEndSpending;
    final projectedSavings = calculateProjectedSavings(
      monthlyAmount: input.monthlyAmount,
      expectedMonthEndSpending: expectedMonthEndSpending,
    );
    final projectedOverspending = calculateProjectedOverspending(
      monthlyAmount: input.monthlyAmount,
      expectedMonthEndSpending: expectedMonthEndSpending,
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
      expectedMonthEndSpending: expectedMonthEndSpending,
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

  void _validateMonthYear(int month, int year) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be between 1 and 12');
    }
    if (year < 1) {
      throw ArgumentError.value(year, 'year', 'Year must be positive');
    }
  }

  void _validateReferenceDate(
    DateTime referenceDate,
    int budgetMonth,
    int budgetYear,
  ) {
    _validateMonthYear(budgetMonth, budgetYear);
    if (referenceDate.month != budgetMonth || referenceDate.year != budgetYear) {
      throw ArgumentError(
        'Reference date ${referenceDate.toIso8601String()} '
        'does not fall within budget period $budgetMonth/$budgetYear',
      );
    }
  }
}
