import 'package:equatable/equatable.dart';

/// Money handed to a tab. [paidDate] is when it changed hands, which may be
/// before it was recorded ([createdAt]).
class TabPayment extends Equatable {
  final String id;
  final String tabId;

  /// Greater than zero, in the tab's currency.
  final double amount;
  final DateTime paidDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TabPayment({
    required this.id,
    required this.tabId,
    required this.amount,
    required this.paidDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  TabPayment copyWith({
    double? amount,
    DateTime? paidDate,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) {
    return TabPayment(
      id: id,
      tabId: tabId,
      amount: amount ?? this.amount,
      paidDate: paidDate ?? this.paidDate,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tabId,
    amount,
    paidDate,
    note,
    createdAt,
    updatedAt,
  ];
}
