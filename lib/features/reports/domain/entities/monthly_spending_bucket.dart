import 'package:equatable/equatable.dart';

/// A spending bucket used by the bar chart.
///
/// For a month view, buckets are weeks; for a year view, buckets are months.
class SpendingBucket extends Equatable {
  final String label;
  final double amount;
  final DateTime startDate;

  const SpendingBucket({
    required this.label,
    required this.amount,
    required this.startDate,
  });

  @override
  List<Object?> get props => [label, amount, startDate];
}
