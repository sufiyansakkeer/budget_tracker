import 'package:equatable/equatable.dart';

/// Where discretionary spending is heading at the average pace of the
/// completed days so far. Informational: it never changes today's amount.
///
/// Either [isReliable] with every projection set, or insufficient history
/// with only [daysNeeded] and [hasAnyExpense].
class SafeToSpendForecast extends Equatable {
  final bool isReliable;

  /// Insufficient only: more days of history needed (0 when only a first
  /// discretionary expense is missing).
  final int daysNeeded;

  /// Whether any discretionary spending exists in the period yet.
  final bool hasAnyExpense;

  /// Completed days (before today) the average is taken over.
  final int completedDays;

  /// Discretionary spending per completed day.
  final double? averageDaily;

  /// Discretionary spending by period end at that pace.
  final double? projectedDiscretionarySpending;

  /// Committed + projected discretionary + bills still due.
  final double? projectedPeriodSpending;

  /// Budget amount − [projectedPeriodSpending] (before kept-aside money and
  /// the savings goal).
  final double? projectedEndBalance;

  /// Free-to-spend money left at period end at this pace; negative = short.
  final double? projectedMargin;

  /// First day free-to-spend money runs out at this pace; `null` exactly
  /// when [projectedMargin] ≥ 0.
  final DateTime? exhaustionDate;

  /// [averageDaily] ÷ today's safe amount; `null` when that amount is 0.
  final double? paceRatio;

  const SafeToSpendForecast.reliable({
    required this.completedDays,
    required double this.averageDaily,
    required double this.projectedDiscretionarySpending,
    required double this.projectedPeriodSpending,
    required double this.projectedEndBalance,
    required double this.projectedMargin,
    required this.exhaustionDate,
    required this.paceRatio,
  }) : isReliable = true,
       daysNeeded = 0,
       hasAnyExpense = true;

  const SafeToSpendForecast.insufficient({
    required this.daysNeeded,
    required this.hasAnyExpense,
    required this.completedDays,
  }) : isReliable = false,
       averageDaily = null,
       projectedDiscretionarySpending = null,
       projectedPeriodSpending = null,
       projectedEndBalance = null,
       projectedMargin = null,
       exhaustionDate = null,
       paceRatio = null;

  @override
  List<Object?> get props => [
    isReliable,
    daysNeeded,
    hasAnyExpense,
    completedDays,
    averageDaily,
    projectedDiscretionarySpending,
    projectedPeriodSpending,
    projectedEndBalance,
    projectedMargin,
    exhaustionDate,
    paceRatio,
  ];
}
