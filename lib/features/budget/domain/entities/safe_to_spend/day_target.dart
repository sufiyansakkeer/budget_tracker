import 'package:equatable/equatable.dart';

/// One day of a running budget: what could be spent that day, what was
/// spent, and the difference.
///
/// Past days use the set-asides known today (bills, money kept aside, the
/// savings goal), so the series shows how spending moved the target, not
/// how the set-asides changed. The last entry is today, equal to the
/// calculator's `dailySafeToSpend` and `todayDiscretionary`.
class DayTarget extends Equatable {
  final DateTime date;

  /// The day's target, never below 0.
  final double target;

  /// Spending that day, without set-aside bill payments.
  final double spent;

  /// [target] − [spent]: left when ≥ 0, over by the magnitude when < 0.
  final double result;

  const DayTarget({
    required this.date,
    required this.target,
    required this.spent,
    required this.result,
  });

  @override
  List<Object?> get props => [date, target, spent, result];
}
