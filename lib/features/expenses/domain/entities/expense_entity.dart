import 'package:equatable/equatable.dart';

/// Immutable expense entity used across the app.
class ExpenseEntity extends Equatable {
  final String id;
  final double amount;
  final String categoryId;
  final String? note;
  final DateTime date;
  final DateTime time;
  final String? receiptImagePath;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseEntity({
    required this.id,
    required this.amount,
    required this.categoryId,
    this.note,
    required this.date,
    required this.time,
    this.receiptImagePath,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ExpenseEntity copyWith({
    String? id,
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
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
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
    );
  }

  @override
  List<Object?> get props => [
    id,
    amount,
    categoryId,
    note,
    date,
    time,
    receiptImagePath,
    tags,
    createdAt,
    updatedAt,
  ];
}
