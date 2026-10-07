import 'package:equatable/equatable.dart';

/// Unpaid bills in the budget's currency, due between today and the period
/// end, that no running or upcoming budget sets money aside for. Disclosed
/// to the user; never deducted.
class UnlinkedCommitmentSummary extends Equatable {
  final int count;
  final double total;

  const UnlinkedCommitmentSummary({required this.count, required this.total});

  static const none = UnlinkedCommitmentSummary(count: 0, total: 0);

  bool get isEmpty => count == 0;

  @override
  List<Object?> get props => [count, total];
}
