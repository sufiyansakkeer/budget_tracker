import 'package:equatable/equatable.dart';

/// Immutable expense entity used across the app.
class ExpenseEntity extends Equatable {
  final String id;
  final String budgetId;
  final double amount;
  final String categoryId;
  final String? note;
  final DateTime date;
  final DateTime time;
  final String? receiptImagePath;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The bill whose occurrence this expense settled when that occurrence was
  /// set aside in this expense's budget (committed spending); null for plain
  /// spending. Written only when the expense is created by paying a bill and
  /// cleared when the expense moves to another budget — never copied by a
  /// duplicate and never written by an edit.
  final String? billId;

  const ExpenseEntity({
    required this.id,
    required this.budgetId,
    required this.amount,
    required this.categoryId,
    this.note,
    required this.date,
    required this.time,
    this.receiptImagePath,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.billId,
  });

  ExpenseEntity copyWith({
    String? id,
    String? budgetId,
    double? amount,
    String? categoryId,
    String? note,
    bool clearNote = false,
    DateTime? date,
    DateTime? time,
    String? receiptImagePath,
    bool clearReceiptImagePath = false,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? billId,
    bool clearBillId = false,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: clearNote ? null : (note ?? this.note),
      date: date ?? this.date,
      time: time ?? this.time,
      receiptImagePath: clearReceiptImagePath
          ? null
          : (receiptImagePath ?? this.receiptImagePath),
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billId: clearBillId ? null : (billId ?? this.billId),
    );
  }

  @override
  List<Object?> get props => [
    id,
    budgetId,
    amount,
    categoryId,
    note,
    date,
    time,
    receiptImagePath,
    tags,
    createdAt,
    updatedAt,
    billId,
  ];
}
