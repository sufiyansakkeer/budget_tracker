import 'package:equatable/equatable.dart';

import 'bill_entity.dart';

/// A bill and its payment history as stored at one moment, captured just
/// before a change (mark paid, pay & record, delete) so Undo can put both
/// back exactly: due date, paid state, paid date, link, timestamps and the
/// same payment rows.
class BillSnapshot extends Equatable {
  /// The bill as it was.
  final BillEntity bill;

  /// Its payment history as it was (any order).
  final List<BillPaymentRecord> payments;

  const BillSnapshot({required this.bill, this.payments = const []});

  @override
  List<Object?> get props => [bill, payments];
}
