import 'package:equatable/equatable.dart';

/// A budget's committed spending: expenses that settled a bill occurrence
/// set aside in that same budget (`expenses.bill_id` set). Safe-to-spend
/// treats them as already-planned money, not discretionary spending.
class CommittedSpending extends Equatable {
  /// Sum of the budget's committed expenses dated inside its period.
  final double periodTotal;

  /// Sum of the budget's committed expenses dated today; 0 when today is
  /// outside the budget's period.
  final double todayTotal;

  const CommittedSpending({
    required this.periodTotal,
    required this.todayTotal,
  });

  static const zero = CommittedSpending(periodTotal: 0, todayTotal: 0);

  @override
  List<Object?> get props => [periodTotal, todayTotal];
}
