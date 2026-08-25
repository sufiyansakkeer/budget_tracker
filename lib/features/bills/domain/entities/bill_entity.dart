import 'package:equatable/equatable.dart';

import 'bill_enums.dart';

/// Immutable bill entity used across the Bills & Reminders feature.
class BillEntity extends Equatable {
  final String id;
  final String title;
  final String? note;
  final double amount;
  final String currency;
  final BillCategory category;
  final DateTime dueDate;
  final DateTime? dueTime;
  final bool isRecurring;
  final RecurrenceType recurrenceType;
  final int recurrenceInterval;
  final bool reminderEnabled;
  final int reminderOffsetDays;
  final bool isPaid;
  final DateTime? paidDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillEntity({
    required this.id,
    required this.title,
    this.note,
    required this.amount,
    required this.currency,
    required this.category,
    required this.dueDate,
    this.dueTime,
    this.isRecurring = false,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.reminderEnabled = false,
    this.reminderOffsetDays = 1,
    this.isPaid = false,
    this.paidDate,
    required this.createdAt,
    required this.updatedAt,
  });

  BillEntity copyWith({
    String? id,
    String? title,
    bool clearNote = false,
    String? note,
    double? amount,
    String? currency,
    BillCategory? category,
    DateTime? dueDate,
    DateTime? dueTime,
    bool clearDueTime = false,
    bool? isRecurring,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    bool? reminderEnabled,
    int? reminderOffsetDays,
    bool? isPaid,
    DateTime? paidDate,
    bool clearPaidDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderOffsetDays: reminderOffsetDays ?? this.reminderOffsetDays,
      isPaid: isPaid ?? this.isPaid,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates the bill's display status based on current date.
  BillStatus get status {
    if (isPaid) return BillStatus.paid;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (due.isBefore(today)) return BillStatus.overdue;
    if (due.isAtSameMomentAs(today)) return BillStatus.dueToday;
    return BillStatus.upcoming;
  }

  /// Deterministic notification ID derived from the bill's ID.
  /// Uses a stable hash so the same bill always maps to the same ID.
  int get notificationId {
    // Use a simple deterministic hash: sum of character codes * 31
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = hash * 31 + id.codeUnitAt(i);
    }
    // Keep in valid notification ID range (positive, < 2^31).
    // The 80000000 prefix identifies bill notifications and avoids collision
    // with budget notification IDs (1001-1999).
    return 80000000 + (hash & 0x7FFFFFFF) % 10000000;
  }

  /// Returns the reminder date/time for scheduling a notification.
  /// Returns null if reminder is disabled or the reminder time is in the past.
  DateTime? get reminderDateTime {
    if (!reminderEnabled) return null;
    final reminderDate = dueDate.subtract(Duration(days: reminderOffsetDays));
    if (dueTime != null) {
      return DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        dueTime!.hour,
        dueTime!.minute,
      );
    }
    // Default to 9:00 AM if no due time specified.
    return DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
      0,
    );
  }

  /// Calculates the next due date for a recurring bill after payment.
  DateTime get nextDueDate {
    switch (recurrenceType) {
      case RecurrenceType.weekly:
        return dueDate.add(Duration(days: 7 * recurrenceInterval));
      case RecurrenceType.monthly:
        return _addMonths(dueDate, recurrenceInterval);
      case RecurrenceType.yearly:
        return _addMonths(dueDate, 12 * recurrenceInterval);
      case RecurrenceType.none:
        return dueDate;
    }
  }

  /// Safely adds months, clamping the day to the last day of the target month.
  static DateTime _addMonths(DateTime date, int months) {
    int targetMonth = date.month + months;
    int targetYear = date.year;
    while (targetMonth > 12) {
      targetMonth -= 12;
      targetYear++;
    }
    while (targetMonth < 1) {
      targetMonth += 12;
      targetYear--;
    }
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > lastDay ? lastDay : date.day;
    return DateTime(targetYear, targetMonth, targetDay);
  }

  @override
  List<Object?> get props => [
    id,
    title,
    note,
    amount,
    currency,
    category,
    dueDate,
    dueTime,
    isRecurring,
    recurrenceType,
    recurrenceInterval,
    reminderEnabled,
    reminderOffsetDays,
    isPaid,
    paidDate,
    createdAt,
    updatedAt,
  ];
}

/// A single payment occurrence for a bill (for payment history).
/// Named BillPaymentRecord to avoid collision with Drift-generated BillPayment table.
class BillPaymentRecord extends Equatable {
  final String id;
  final String billId;
  final double amount;
  final String currency;
  final DateTime paidDate;
  final DateTime createdAt;

  const BillPaymentRecord({
    required this.id,
    required this.billId,
    required this.amount,
    required this.currency,
    required this.paidDate,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, billId, amount, currency, paidDate, createdAt];
}
