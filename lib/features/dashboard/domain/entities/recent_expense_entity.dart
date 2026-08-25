import 'package:equatable/equatable.dart';

/// Represents a recent expense for display on the dashboard.
class RecentExpenseEntity extends Equatable {
  final String id;
  final double amount;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColorHex;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const RecentExpenseEntity({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColorHex,
    this.note,
    required this.date,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    amount,
    categoryId,
    categoryName,
    categoryIcon,
    categoryColorHex,
    note,
    date,
    createdAt,
  ];
}
