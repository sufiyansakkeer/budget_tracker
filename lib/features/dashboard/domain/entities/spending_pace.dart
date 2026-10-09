import 'package:equatable/equatable.dart';

/// How a running budget's discretionary spending has built up day by day,
/// against an even pace through the period. Informational: it never changes
/// today's safe amount.
///
/// * [plannedTotal] is the money the period has for discretionary spending
///   as things stand today: the budget amount minus bill payments already
///   made from it, bills still due, money kept aside and the savings goal
///   (= raw spendable + discretionary spent so far).
/// * The planned line rises evenly from 0 on the day before the period to
///   [plannedTotal] on its last day.
/// * [cumulative] holds the actual discretionary spending at the end of each
///   day from the first day through today (today still in progress).
///
/// Built by `SpendingPaceBuilder`; amounts are in [currency].
class SpendingPace extends Equatable {
  final String currency;
  final int totalDays;

  /// Days of the period up to and including today.
  final int daysPassed;

  /// Discretionary spending at the end of day 1, 2, … [daysPassed].
  final List<double> cumulative;

  final double plannedTotal;

  /// Where the even pace stands at the end of today:
  /// [plannedTotal] × [daysPassed] ÷ [totalDays].
  final double plannedToDate;

  /// Discretionary spending so far (the last value of [cumulative]).
  final double actualToDate;

  const SpendingPace({
    required this.currency,
    required this.totalDays,
    required this.daysPassed,
    required this.cumulative,
    required this.plannedTotal,
    required this.plannedToDate,
    required this.actualToDate,
  });

  /// Spending minus the even pace so far: above 0 means faster than planned.
  double get aheadOfPlan => actualToDate - plannedToDate;

  /// A pace is worth showing once there are a few days to compare, some
  /// spending, and money planned for the period (the same three-day minimum
  /// as the forecast).
  bool get isMeaningful =>
      daysPassed >= 3 && actualToDate > 0 && plannedTotal > 0;

  @override
  List<Object?> get props => [
    currency,
    totalDays,
    daysPassed,
    cumulative,
    plannedTotal,
    plannedToDate,
    actualToDate,
  ];
}
