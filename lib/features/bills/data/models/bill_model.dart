import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';

/// Maps between the Drift [Bill] row and the domain [BillEntity].
class BillModel {
  BillModel._();

  /// Maps a Drift Bill row to a domain BillEntity.
  static BillEntity toEntity(Bill row) {
    return BillEntity(
      id: row.id,
      title: row.title,
      note: row.note,
      amount: row.amount,
      currency: row.currency,
      category: _parseCategory(row.category),
      dueDate: row.dueDate,
      dueTime: row.dueTime,
      isRecurring: row.isRecurring,
      recurrenceType: _parseRecurrenceType(row.recurrenceType),
      recurrenceInterval: row.recurrenceInterval,
      reminderEnabled: row.reminderEnabled,
      reminderOffsetDays: row.reminderOffsetDays,
      isPaid: row.isPaid,
      paidDate: row.paidDate,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Maps a domain BillEntity to a Drift BillsCompanion for inserts.
  static BillsCompanion toInsertCompanion(BillEntity entity) {
    return BillsCompanion.insert(
      id: entity.id,
      title: entity.title,
      note: Value(entity.note),
      amount: entity.amount,
      currency: entity.currency,
      category: entity.category.name,
      dueDate: entity.dueDate,
      dueTime: Value(entity.dueTime),
      isRecurring: Value(entity.isRecurring),
      recurrenceType: Value(entity.recurrenceType.name),
      recurrenceInterval: Value(entity.recurrenceInterval),
      reminderEnabled: Value(entity.reminderEnabled),
      reminderOffsetDays: Value(entity.reminderOffsetDays),
      isPaid: Value(entity.isPaid),
      paidDate: Value(entity.paidDate),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  /// Maps a domain BillEntity to a BillsCompanion for updates.
  static BillsCompanion toUpdateCompanion(BillEntity entity) {
    return BillsCompanion(
      id: Value(entity.id),
      title: Value(entity.title),
      note: Value(entity.note),
      amount: Value(entity.amount),
      currency: Value(entity.currency),
      category: Value(entity.category.name),
      dueDate: Value(entity.dueDate),
      dueTime: Value(entity.dueTime),
      isRecurring: Value(entity.isRecurring),
      recurrenceType: Value(entity.recurrenceType.name),
      recurrenceInterval: Value(entity.recurrenceInterval),
      reminderEnabled: Value(entity.reminderEnabled),
      reminderOffsetDays: Value(entity.reminderOffsetDays),
      isPaid: Value(entity.isPaid),
      paidDate: Value(entity.paidDate),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  /// Maps a Drift BillPayment row to a domain BillPaymentRecord.
  static BillPaymentRecord paymentToEntity(BillPayment row) {
    return BillPaymentRecord(
      id: row.id,
      billId: row.billId,
      amount: row.amount,
      currency: row.currency,
      paidDate: row.paidDate,
      createdAt: row.createdAt,
    );
  }

  /// Maps a domain BillPaymentRecord to a BillPaymentsCompanion for inserts.
  static BillPaymentsCompanion paymentToCompanion(BillPaymentRecord payment) {
    return BillPaymentsCompanion.insert(
      id: payment.id,
      billId: payment.billId,
      amount: payment.amount,
      currency: payment.currency,
      paidDate: payment.paidDate,
      createdAt: Value(payment.createdAt),
    );
  }

  static BillCategory _parseCategory(String value) {
    return BillCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BillCategory.other,
    );
  }

  static RecurrenceType _parseRecurrenceType(String value) {
    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrenceType.none,
    );
  }
}
