import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/usecases/schedule_bill_reminder_usecase.dart';

/// The reminder text is for the day it fires. It used to be worked out on the
/// day it was scheduled, so a 1-day reminder for a bill 30 days away said
/// "due in 30 days" the day before.
void main() {
  BillEntity bill({required int remindDaysBefore, String currency = 'INR'}) =>
      BillEntity(
        id: 'power',
        title: 'Electricity',
        amount: 1850.5,
        currency: currency,
        category: BillCategory.electricity,
        // Far from today: the text must not depend on when it is scheduled.
        dueDate: DateTime.now().addDays(30),
        reminderEnabled: true,
        reminderOffsetDays: remindDaysBefore,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

  test('a reminder the day before says tomorrow', () {
    final (title, body) = BillReminderService.reminderText(
      bill(remindDaysBefore: 1),
    );
    expect(title, "Tomorrow's Bill");
    expect(body, contains('due tomorrow'));
  });

  test('a reminder on the day says today', () {
    final (title, body) = BillReminderService.reminderText(
      bill(remindDaysBefore: 0),
    );
    expect(title, 'Bill Due Today');
    expect(body, contains('due today'));
  });

  test('a reminder 3 days before says in 3 days', () {
    final (_, body) = BillReminderService.reminderText(
      bill(remindDaysBefore: 3),
    );
    expect(body, contains('due in 3 days'));
  });

  test('the amount is formatted as money, not rounded by hand', () {
    final (_, body) = BillReminderService.reminderText(
      bill(remindDaysBefore: 1, currency: 'OMR'),
    );
    expect(body, contains(CurrencyFormatter.format(1850.5, code: 'OMR')));
    expect(body, isNot(contains('OMR1851')));
  });
}
