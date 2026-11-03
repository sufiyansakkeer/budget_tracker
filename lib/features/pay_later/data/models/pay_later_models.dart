import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/payment_allocation.dart';
import '../../domain/entities/settle_rhythm.dart';
import '../../domain/entities/tab_payment.dart';

/// Row ↔ entity mapping for the Pay Later tables. The rhythm is stored as a
/// kind string plus the columns that kind uses; the others stay null.
class PayLaterModels {
  PayLaterModels._();

  static const _onDemand = 'on_demand';
  static const _everyDays = 'every_days';
  static const _monthlyDay = 'monthly_day';
  static const _manualDate = 'manual_date';

  static PayLaterTab tabToEntity(PayLaterAccount row) {
    return PayLaterTab(
      id: row.id,
      name: row.name,
      category: PayLaterTabCategory.fromKey(row.category),
      currency: row.currency,
      note: row.note,
      contact: row.contact,
      defaultCategoryId: row.defaultCategoryId,
      rhythm: rhythmFromRow(row),
      reminderEnabled: row.reminderEnabled,
      reminderOffsetDays: row.reminderOffsetDays,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static SettleRhythm rhythmFromRow(PayLaterAccount row) {
    switch (row.rhythm) {
      case _everyDays:
        final days = row.rhythmDays;
        final anchor = row.rhythmAnchor;
        if (days != null && anchor != null) {
          return EveryDays(days: days, anchor: anchor);
        }
        return _coerced(row, 'every_days without days or anchor');
      case _monthlyDay:
        final day = row.rhythmDayOfMonth;
        return day == null
            ? _coerced(row, 'monthly_day without a day')
            : MonthlyDay(day: day);
      case _manualDate:
        return ManualDate(
          nextSettleDate: row.nextSettleDate,
          anchor: row.rhythmAnchor,
        );
      case _onDemand:
        return const OnDemand();
      default:
        return _coerced(row, 'unknown rhythm "${row.rhythm}"');
    }
  }

  /// A row that can't be read as its rhythm is read as on demand (no
  /// periods, no reminder, never overdue). Logged, so a tab that silently
  /// lost its reminders leaves a trace.
  static SettleRhythm _coerced(PayLaterAccount row, String why) {
    developer.log(
      'Tab ${row.id}: $why; reading it as on demand',
      name: 'PayLaterModels',
    );
    return const OnDemand();
  }

  static PayLaterAccountsCompanion tabToCompanion(PayLaterTab tab) {
    final rhythm = tab.rhythm;
    final String kind;
    int? days;
    int? dayOfMonth;
    DateTime? anchor;
    DateTime? nextSettle;
    switch (rhythm) {
      case OnDemand():
        kind = _onDemand;
      case EveryDays():
        kind = _everyDays;
        days = rhythm.days;
        anchor = rhythm.anchor;
      case MonthlyDay():
        kind = _monthlyDay;
        dayOfMonth = rhythm.day;
      case ManualDate():
        kind = _manualDate;
        anchor = rhythm.anchor;
        nextSettle = rhythm.nextSettleDate;
    }
    return PayLaterAccountsCompanion(
      id: Value(tab.id),
      name: Value(tab.name),
      category: Value(tab.category.key),
      currency: Value(tab.currency),
      note: Value(tab.note),
      contact: Value(tab.contact),
      defaultCategoryId: Value(tab.defaultCategoryId),
      rhythm: Value(kind),
      rhythmDays: Value(days),
      rhythmDayOfMonth: Value(dayOfMonth),
      rhythmAnchor: Value(anchor),
      nextSettleDate: Value(nextSettle),
      reminderEnabled: Value(tab.reminderEnabled),
      reminderOffsetDays: Value(tab.reminderOffsetDays),
      isArchived: Value(tab.isArchived),
      createdAt: Value(tab.createdAt),
      updatedAt: Value(tab.updatedAt),
    );
  }

  static TabPayment paymentToEntity(PayLaterPayment row) {
    return TabPayment(
      id: row.id,
      tabId: row.accountId,
      amount: row.amount,
      paidDate: row.paidDate,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static PayLaterPaymentsCompanion paymentToCompanion(TabPayment payment) {
    return PayLaterPaymentsCompanion(
      id: Value(payment.id),
      accountId: Value(payment.tabId),
      amount: Value(payment.amount),
      paidDate: Value(payment.paidDate),
      note: Value(payment.note),
      createdAt: Value(payment.createdAt),
      updatedAt: Value(payment.updatedAt),
    );
  }

  static PaymentAllocation allocationToEntity(PayLaterAllocation row) {
    return PaymentAllocation(
      id: row.id,
      paymentId: row.paymentId,
      expenseId: row.expenseId,
      amount: row.amount,
      isManual: row.isManual,
      createdAt: row.createdAt,
    );
  }

  static PayLaterAllocationsCompanion allocationToCompanion(
    PaymentAllocation allocation,
  ) {
    return PayLaterAllocationsCompanion(
      id: Value(allocation.id),
      paymentId: Value(allocation.paymentId),
      expenseId: Value(allocation.expenseId),
      amount: Value(allocation.amount),
      isManual: Value(allocation.isManual),
      createdAt: Value(allocation.createdAt),
    );
  }
}
