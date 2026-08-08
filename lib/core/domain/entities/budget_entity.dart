import 'package:equatable/equatable.dart';

/// Represents a budget record stored in the local database.
///
/// A budget can span any custom date range (not just calendar months) and is
/// fully independent from other budgets. Each budget has its own amount,
/// currency, date range, expenses, and configuration.
class BudgetEntity extends Equatable {
  final String id;
  final String name;
  final double monthlyAmount;
  final double remainingAmount;
  final String currency;
  final DateTime startDate;
  final DateTime endDate;
  final bool isArchived;
  final String? color;
  final String? icon;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetEntity({
    required this.id,
    required this.name,
    required this.monthlyAmount,
    required this.remainingAmount,
    required this.currency,
    required this.startDate,
    required this.endDate,
    this.isArchived = false,
    this.color,
    this.icon,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total number of days in this budget's period (inclusive).
  int get totalDays => endDate.difference(startDate).inDays + 1;

  /// Number of days elapsed from the budget start up to [date] (inclusive).
  int daysElapsed(DateTime date) {
    final ref = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final diff = ref.difference(start).inDays;
    if (diff < 0) return 0;
    return diff + 1;
  }

  /// Number of days remaining from [date] through the budget end (inclusive).
  int daysRemaining(DateTime date) {
    final ref = DateTime(date.year, date.month, date.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = end.difference(ref).inDays;
    if (diff < 0) return 0;
    return diff + 1;
  }

  /// Whether [date] falls within this budget's period.
  bool isActiveOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Whether this budget is currently relevant (not archived and today is in range).
  bool get isActive => !isArchived && isActiveOn(DateTime.now());

  BudgetEntity copyWith({
    String? id,
    String? name,
    double? monthlyAmount,
    double? remainingAmount,
    String? currency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isArchived,
    String? color,
    String? icon,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isArchived: isArchived ?? this.isArchived,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    monthlyAmount,
    remainingAmount,
    currency,
    startDate,
    endDate,
    isArchived,
    color,
    icon,
    notes,
    createdAt,
    updatedAt,
  ];
}
