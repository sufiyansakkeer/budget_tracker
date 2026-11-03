import 'package:equatable/equatable.dart';

/// How much of a payment settles one purchase (an expense on the tab).
class PaymentAllocation extends Equatable {
  final String id;
  final String paymentId;
  final String expenseId;

  /// Greater than zero, in the tab's currency.
  final double amount;

  /// The user chose this purchase explicitly. Automatic (FIFO) allocations
  /// are trimmed before manual ones.
  final bool isManual;
  final DateTime createdAt;

  const PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.expenseId,
    required this.amount,
    required this.isManual,
    required this.createdAt,
  });

  PaymentAllocation copyWith({double? amount}) {
    return PaymentAllocation(
      id: id,
      paymentId: paymentId,
      expenseId: expenseId,
      amount: amount ?? this.amount,
      isManual: isManual,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    paymentId,
    expenseId,
    amount,
    isManual,
    createdAt,
  ];
}
