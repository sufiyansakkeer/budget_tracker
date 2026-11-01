import '../../../../core/currency/money_math.dart';
import '../entities/budget_calculation_input.dart';
import '../entities/budget_status.dart';
import '../entities/budget_summary_entity.dart';
import '../entities/budget_thresholds.dart';
import '../../../../core/dates/calendar_dates.dart' as dates;

/// Pure calculation engine for all budget-related metrics.
///
/// Contains no database, UI, or Flutter dependencies.
/// All methods are deterministic and unit-testable.
class BudgetCalculationService {
  // The last summary is memoized; its key includes the currency it was
  // labelled with.
  BudgetCalculationInput? _summaryInput;
  String? _summaryCurrency;
  BudgetSummaryEntity? _cachedSummary;

  /// Whole calendar days from the date of [from] to the date of [to]
  /// (negative when [to] is earlier). Time of day is ignored.
  ///
  /// See [dates.calendarDaysBetween]: a daylight-saving change between the
  /// two dates (a 23- or 25-hour local day) cannot shift the result.
  ///
  /// Example: 8 Mar 2026 → 9 Mar 2026 = 1 in every time zone.
  static int calendarDaysBetween(DateTime from, DateTime to) =>
      dates.calendarDaysBetween(from, to);

  /// Returns the total number of days in the budget period (inclusive).
  ///
  /// Only the dates count: a period stored as 1 Aug 12:00 → 31 Aug 00:00 is
  /// still 31 days.
  int daysInPeriod({required DateTime startDate, required DateTime endDate}) {
    _validateDateRange(startDate, endDate);
    return calendarDaysBetween(startDate, endDate) + 1;
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
    final diff = calendarDaysBetween(startDate, referenceDate);
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
    final remaining = calendarDaysBetween(referenceDate, endDate) + 1;
    return remaining < 1 ? 1 : remaining;
  }

  /// Remaining budget after subtracting total spending.
  ///
  /// With [currency], the subtraction is done in its minor units
  /// ([MoneyMath.subtract]), so a budget spent to exactly zero is 0, not a
  /// rounding remainder shown as over budget.
  double calculateRemainingBudget({
    required double monthlyAmount,
    required double totalSpent,
    String? currency,
  }) {
    if (currency == null) return monthlyAmount - totalSpent;
    return MoneyMath.forCurrency(currency).subtract(monthlyAmount, totalSpent);
  }

  /// Primitive division used by [calculateTodaySafeSpending].
  ///
  /// Formula: remainingBudget ÷ remainingDays (remainingDays floored at 1).
  ///
  /// Callers that want "today's safe spending" must use
  /// [calculateTodaySafeSpending] so today's expenses are added back first;
  /// this method alone shrinks as the day's spending grows.
  double calculateDailyAllowance({
    required double remainingBudget,
    required int remainingDays,
  }) {
    final safeDays = remainingDays < 1 ? 1 : remainingDays;
    return remainingBudget / safeDays;
  }

  /// Today's safe spending — the single formula used by every screen,
  /// notification and the home-screen widget.
  ///
  /// Formula: (remainingBudget + todaySpending) ÷ remainingDays
  ///
  /// Today's expenses are added back before dividing so the figure stays
  /// fixed for the whole day: spending counts *against* today's limit instead
  /// of silently lowering it after every purchase. Tomorrow the value is
  /// recomputed from what is actually left.
  double calculateTodaySafeSpending({
    required double remainingBudget,
    required double todaySpending,
    required int remainingDays,
  }) {
    return calculateDailyAllowance(
      remainingBudget: remainingBudget + todaySpending,
      remainingDays: remainingDays,
    );
  }

  /// Budget utilization as a ratio (0.0–1.0+).
  double calculateBudgetUtilization({
    required double totalSpent,
    required double monthlyAmount,
  }) {
    if (monthlyAmount <= 0) return 0;
    return totalSpent / monthlyAmount;
  }

  /// Percentage of the budget amount that has been spent.
  double calculateSpendingPercentage({
    required double totalSpent,
    required double monthlyAmount,
  }) {
    if (monthlyAmount <= 0) return 0;
    return (totalSpent / monthlyAmount) * 100;
  }

  /// Percentage of the budget amount still remaining.
  double calculateRemainingPercentage({
    required double remainingBudget,
    required double monthlyAmount,
  }) {
    if (monthlyAmount <= 0) return 0;
    return (remainingBudget / monthlyAmount) * 100;
  }

  /// Average daily spending based on days passed in the budget period.
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
    if (_summaryInput == input &&
        _summaryCurrency == currency &&
        _cachedSummary != null) {
      return _cachedSummary!;
    }

    final remainingBudget = calculateRemainingBudget(
      monthlyAmount: input.monthlyAmount,
      totalSpent: input.totalSpent,
      currency: currency,
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
    final dailySafeSpending = calculateTodaySafeSpending(
      remainingBudget: remainingBudget,
      todaySpending: input.todaySpending,
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

    _summaryInput = input;
    _summaryCurrency = currency;
    _cachedSummary = summary;
    return summary;
  }

  void _validateDateRange(DateTime startDate, DateTime endDate) {
    if (calendarDaysBetween(startDate, endDate) < 0) {
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
    if (calendarDaysBetween(startDate, referenceDate) < 0 ||
        calendarDaysBetween(referenceDate, endDate) < 0) {
      throw ArgumentError(
        'Reference date ${referenceDate.toIso8601String()} '
        'does not fall within budget period '
        '${startDate.toIso8601String()} – ${endDate.toIso8601String()}',
      );
    }
  }
}
