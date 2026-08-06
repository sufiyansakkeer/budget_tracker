import 'dart:math' as math;

import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../entities/category_analytics.dart';
import '../entities/category_slice.dart';
import '../entities/daily_spending_point.dart';
import '../entities/monthly_spending_bucket.dart';
import '../entities/report_data.dart';
import '../entities/report_overview.dart';
import '../entities/report_period.dart';
import '../entities/spending_trend.dart';
import '../entities/time_analytics.dart';
import '../entities/weekly_comparison.dart';

/// Pure calculation engine for all report analytics.
///
/// Contains no database, UI, or Flutter dependencies. All methods are
/// deterministic and unit-testable. Existing repositories and the Budget
/// Engine supply inputs; this service only derives report aggregates.
class AnalyticsService {
  const AnalyticsService();

  /// Builds a complete [ReportData] snapshot for [range] from filtered expenses.
  ReportData buildReportData({
    required ReportRange range,
    required List<ExpenseEntity> filteredExpenses,
    required List<ExpenseCategory> categories,
    required ExpenseHistoryFilter filter,
    BudgetEntity? currentBudget,
    double currentMonthSpent = 0,
    double currentMonthBudget = 0,
  }) {
    final weeklyComparison =
        range.period == ReportPeriod.thisWeek ||
            range.period == ReportPeriod.lastWeek
        ? calculateWeeklyComparison(expenses: filteredExpenses, range: range)
        : null;

    return ReportData(
      range: range,
      filteredExpenses: filteredExpenses,
      categories: categories,
      filter: filter,
      overview: calculateOverview(
        expenses: filteredExpenses,
        dayCount: range.dayCount,
      ),
      dailySpending: calculateDailySpending(
        expenses: filteredExpenses,
        range: range,
      ),
      spendingBuckets: calculateBuckets(
        expenses: filteredExpenses,
        range: range,
      ),
      categorySlices: calculateCategorySlices(
        expenses: filteredExpenses,
        categories: categories,
      ),
      categoryAnalytics: calculateCategoryAnalytics(
        expenses: filteredExpenses,
        categories: categories,
      ),
      timeAnalytics: calculateTimeAnalytics(
        expenses: filteredExpenses,
        range: range,
      ),
      trend: calculateTrend(expenses: filteredExpenses, range: range),
      weeklyComparison: weeklyComparison,
      currentBudget: currentBudget,
      currentMonthSpent: currentMonthSpent,
      currentMonthBudget: currentMonthBudget,
    );
  }

  /// Computes the summary overview for a set of expenses.
  ReportOverview calculateOverview({
    required List<ExpenseEntity> expenses,
    required int dayCount,
  }) {
    if (expenses.isEmpty) return ReportOverview.empty;

    var total = 0.0;
    var highest = double.negativeInfinity;
    var lowest = double.infinity;

    for (final expense in expenses) {
      total += expense.amount;
      if (expense.amount > highest) highest = expense.amount;
      if (expense.amount < lowest) lowest = expense.amount;
    }

    return ReportOverview(
      totalSpending: total,
      totalTransactions: expenses.length,
      averageDailySpending: total / (dayCount < 1 ? 1 : dayCount),
      averageTransactionAmount: total / expenses.length,
      highestExpense: highest,
      lowestExpense: lowest,
    );
  }

  /// Daily spending series covering every day in [range] (zero-filled).
  List<DailySpendingPoint> calculateDailySpending({
    required List<ExpenseEntity> expenses,
    required ReportRange range,
  }) {
    final byDay = <DateTime, double>{};
    for (final expense in expenses) {
      final day = _dateOnly(expense.date);
      byDay[day] = (byDay[day] ?? 0) + expense.amount;
    }

    final points = <DailySpendingPoint>[];
    for (var i = 0; i < range.dayCount; i++) {
      final date = range.start.add(Duration(days: i));
      final key = _dateOnly(date);
      points.add(DailySpendingPoint(date: key, amount: byDay[key] ?? 0));
    }
    return points;
  }

  /// Groups expenses into weekly or monthly buckets depending on the period.
  List<SpendingBucket> calculateBuckets({
    required List<ExpenseEntity> expenses,
    required ReportRange range,
  }) {
    if (range.period == ReportPeriod.thisYear ||
        (range.period == ReportPeriod.custom && range.dayCount > 62)) {
      return _monthlyBuckets(expenses, range);
    }
    return _weeklyBuckets(expenses, range);
  }

  List<SpendingBucket> _weeklyBuckets(
    List<ExpenseEntity> expenses,
    ReportRange range,
  ) {
    final buckets = <SpendingBucket>[];
    var cursor = _startOfWeek(range.start);
    while (!cursor.isAfter(range.end)) {
      final weekStart = cursor;
      final weekEnd = cursor.add(const Duration(days: 6));
      var amount = 0.0;
      for (final expense in expenses) {
        final d = _dateOnly(expense.date);
        if (!d.isBefore(weekStart) && !d.isAfter(weekEnd)) {
          amount += expense.amount;
        }
      }
      buckets.add(
        SpendingBucket(
          label: _bucketLabel(weekStart, range.end),
          amount: amount,
          startDate: weekStart,
        ),
      );
      cursor = weekEnd.add(const Duration(days: 1));
    }
    return buckets;
  }

  List<SpendingBucket> _monthlyBuckets(
    List<ExpenseEntity> expenses,
    ReportRange range,
  ) {
    final buckets = <SpendingBucket>[];
    var cursor = DateTime(range.start.year, range.start.month, 1);
    final finalMonth = DateTime(range.end.year, range.end.month, 1);
    while (!cursor.isAfter(finalMonth)) {
      final monthStart = cursor;
      final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
      var amount = 0.0;
      for (final expense in expenses) {
        final d = _dateOnly(expense.date);
        if (!d.isBefore(monthStart) && !d.isAfter(monthEnd)) {
          amount += expense.amount;
        }
      }
      buckets.add(
        SpendingBucket(
          label: _monthLabel(monthStart),
          amount: amount,
          startDate: monthStart,
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return buckets;
  }

  /// Category distribution for the pie chart (as percentages of total).
  List<CategorySlice> calculateCategorySlices({
    required List<ExpenseEntity> expenses,
    required List<ExpenseCategory> categories,
  }) {
    if (expenses.isEmpty) return const [];

    final totals = <String, double>{};
    for (final expense in expenses) {
      totals[expense.categoryId] =
          (totals[expense.categoryId] ?? 0) + expense.amount;
    }

    final total = totals.values.fold(0.0, (a, b) => a + b);
    final nameById = {for (final c in categories) c.id: c.name};
    final colorById = {for (final c in categories) c.id: c.colorHex};

    final slices = totals.entries.map((entry) {
      final categoryId = entry.key;
      return CategorySlice(
        categoryId: categoryId,
        categoryName: nameById[categoryId] ?? 'Unknown',
        colorHex: colorById[categoryId] ?? '#8395A7',
        amount: entry.value,
        percentage: total <= 0 ? 0 : (entry.value / total) * 100,
      );
    }).toList();

    slices.sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  /// Full per-category analytics sorted by highest spending first.
  List<CategoryAnalytics> calculateCategoryAnalytics({
    required List<ExpenseEntity> expenses,
    required List<ExpenseCategory> categories,
  }) {
    if (expenses.isEmpty) return const [];

    final perCategory = <String, List<ExpenseEntity>>{};
    for (final expense in expenses) {
      perCategory.putIfAbsent(expense.categoryId, () => []).add(expense);
    }

    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final nameById = {for (final c in categories) c.id: c.name};
    final colorById = {for (final c in categories) c.id: c.colorHex};

    final result = perCategory.entries.map((entry) {
      final list = entry.value;
      var sum = 0.0;
      var highest = double.negativeInfinity;
      var lowest = double.infinity;
      for (final expense in list) {
        sum += expense.amount;
        if (expense.amount > highest) highest = expense.amount;
        if (expense.amount < lowest) lowest = expense.amount;
      }
      return CategoryAnalytics(
        categoryId: entry.key,
        categoryName: nameById[entry.key] ?? 'Unknown',
        colorHex: colorById[entry.key] ?? '#8395A7',
        totalAmount: sum,
        transactionCount: list.length,
        averageTransaction: sum / list.length,
        highestTransaction: highest,
        lowestTransaction: lowest,
        percentageOfTotal: total <= 0 ? 0 : (sum / total) * 100,
      );
    }).toList();

    result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return result;
  }

  /// Time-based analytics: most/least active days, weekday & weekend totals.
  TimeAnalytics calculateTimeAnalytics({
    required List<ExpenseEntity> expenses,
    required ReportRange range,
  }) {
    if (expenses.isEmpty) return TimeAnalytics.empty;

    final byDay = <DateTime, double>{};
    final countByDay = <DateTime, int>{};
    final byWeekday = <int, double>{};
    final byWeekdayCount = <int, int>{};

    var weekdaySpending = 0.0;
    var weekendSpending = 0.0;

    for (final expense in expenses) {
      final day = _dateOnly(expense.date);
      byDay[day] = (byDay[day] ?? 0) + expense.amount;
      countByDay[day] = (countByDay[day] ?? 0) + 1;

      final weekday = expense.date.weekday;
      byWeekday[weekday] = (byWeekday[weekday] ?? 0) + expense.amount;
      byWeekdayCount[weekday] = (byWeekdayCount[weekday] ?? 0) + 1;

      if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
        weekendSpending += expense.amount;
      } else {
        weekdaySpending += expense.amount;
      }
    }

    DateTime? mostExpensiveDay;
    DateTime? cheapestDay;
    DateTime? mostActiveDay;
    DateTime? leastActiveDay;
    var maxAmount = double.negativeInfinity;
    var minAmount = double.infinity;
    var maxCount = -1;
    var minCount = double.infinity;

    for (final entry in byDay.entries) {
      if (entry.value > maxAmount) {
        maxAmount = entry.value;
        mostExpensiveDay = entry.key;
      }
      if (entry.value < minAmount) {
        minAmount = entry.value;
        cheapestDay = entry.key;
      }
    }
    for (final entry in countByDay.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostActiveDay = entry.key;
      }
      if (entry.value < minCount) {
        minCount = entry.value.toDouble();
        leastActiveDay = entry.key;
      }
    }

    int? highestWeekday;
    var maxWeekdayAmount = double.negativeInfinity;
    for (final entry in byWeekday.entries) {
      if (entry.value > maxWeekdayAmount) {
        maxWeekdayAmount = entry.value;
        highestWeekday = entry.key;
      }
    }

    final breakdown = <WeekdaySpending>[];
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      breakdown.add(
        WeekdaySpending(
          weekday: d,
          amount: byWeekday[d] ?? 0,
          transactionCount: byWeekdayCount[d] ?? 0,
        ),
      );
    }

    return TimeAnalytics(
      mostExpensiveDay: mostExpensiveDay,
      cheapestDay: cheapestDay,
      mostActiveDay: mostActiveDay,
      leastActiveDay: leastActiveDay,
      highestSpendingWeekday: highestWeekday,
      weekdaySpending: weekdaySpending,
      weekendSpending: weekendSpending,
      weekdayBreakdown: breakdown,
    );
  }

  /// Trend indicators: averages, growth vs previous comparable range, and
  /// consistency (inverse coefficient of variation of daily spending).
  SpendingTrend calculateTrend({
    required List<ExpenseEntity> expenses,
    required ReportRange range,
  }) {
    if (expenses.isEmpty) {
      return SpendingTrend.empty;
    }

    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final dayCount = range.dayCount < 1 ? 1 : range.dayCount;
    final dailyAverage = total / dayCount;
    final weeklyAverage = dailyAverage * 7;
    final monthlyAverage = dailyAverage * 30;

    // Growth vs the immediately preceding equivalent-length range.
    var growthRate = 0.0;
    final previousStart = range.start.subtract(Duration(days: dayCount));
    final previousEnd = range.start.subtract(const Duration(days: 1));
    final previousTotal = expenses
        .where((e) {
          final d = _dateOnly(e.date);
          return !d.isBefore(_dateOnly(previousStart)) &&
              !d.isAfter(_dateOnly(previousEnd));
        })
        .fold<double>(0, (s, e) => s + e.amount);

    if (previousTotal > 0) {
      growthRate = (total - previousTotal) / previousTotal;
    }

    // Consistency from daily totals (coefficient of variation, inverted).
    double consistencyScore = 1.0;
    double sumSquares = 0;
    for (final point in calculateDailySpending(
      expenses: expenses,
      range: range,
    )) {
      final diff = point.amount - dailyAverage;
      sumSquares += diff * diff;
    }
    final variance = sumSquares / dayCount;
    final stdDev = math.sqrt(variance);
    if (dailyAverage > 0) {
      final cv = stdDev / dailyAverage;
      consistencyScore = (1 - cv).clamp(0.0, 1.0).toDouble();
    }

    // Improving if the second half of the range is below the first half.
    var improving = false;
    if (dayCount >= 2) {
      final split = dayCount ~/ 2;
      final firstHalf = _sumRange(expenses, range.start, split);
      final secondHalf = _sumRange(
        expenses,
        range.start.add(Duration(days: split)),
        dayCount - split,
      );
      if (firstHalf > 0) {
        improving = secondHalf < firstHalf;
      }
    }

    return SpendingTrend(
      dailyAverage: dailyAverage,
      weeklyAverage: weeklyAverage,
      monthlyAverage: monthlyAverage,
      growthRate: growthRate,
      consistencyScore: consistencyScore,
      isImproving: improving,
    );
  }

  /// Compares the selected week against the immediately preceding week.
  WeeklyComparison calculateWeeklyComparison({
    required List<ExpenseEntity> expenses,
    required ReportRange range,
  }) {
    final current = _sumRange(expenses, range.start, range.dayCount);

    final previousStart = range.start.subtract(Duration(days: range.dayCount));
    final previous = _sumRange(expenses, previousStart, range.dayCount);

    final difference = current - previous;
    final percentageChange = previous > 0
        ? ((current - previous) / previous) * 100
        : (current > 0 ? 100.0 : 0.0);

    return WeeklyComparison(
      currentWeekSpending: current,
      previousWeekSpending: previous,
      difference: difference,
      percentageChange: percentageChange,
    );
  }

  double _sumRange(List<ExpenseEntity> expenses, DateTime start, int days) {
    final end = start.add(Duration(days: days - 1));
    var total = 0.0;
    for (final expense in expenses) {
      final d = _dateOnly(expense.date);
      if (!d.isBefore(_dateOnly(start)) && !d.isAfter(_dateOnly(end))) {
        total += expense.amount;
      }
    }
    return total;
  }

  DateTime _startOfWeek(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _bucketLabel(DateTime weekStart, DateTime rangeEnd) {
    return '${weekStart.day}/${weekStart.month}';
  }

  String _monthLabel(DateTime month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month.month - 1];
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
