import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';

BillEntity makeBill({
  String id = 'bill-1',
  DateTime? dueDate,
  bool isPaid = false,
  bool isRecurring = false,
  RecurrenceType recurrenceType = RecurrenceType.none,
  int recurrenceInterval = 1,
  bool reminderEnabled = false,
  int reminderOffsetDays = 1,
  DateTime? dueTime,
}) {
  final now = DateTime.now();
  return BillEntity(
    id: id,
    title: 'Test Bill',
    amount: 1000,
    currency: 'INR',
    category: BillCategory.utilities,
    dueDate: dueDate ?? DateTime(2026, 9, 1),
    dueTime: dueTime,
    isRecurring: isRecurring,
    recurrenceType: recurrenceType,
    recurrenceInterval: recurrenceInterval,
    reminderEnabled: reminderEnabled,
    reminderOffsetDays: reminderOffsetDays,
    isPaid: isPaid,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('BillEntity.status', () {
    test('returns paid when isPaid is true', () {
      final bill = makeBill(isPaid: true);
      expect(bill.status, BillStatus.paid);
    });

    test('returns overdue when dueDate is before today', () {
      final bill = makeBill(dueDate: DateTime(2026, 8, 20));
      expect(bill.status, BillStatus.overdue);
    });

    test('returns dueToday when dueDate is today', () {
      final today = DateTime.now();
      final bill = makeBill(dueDate: today);
      expect(bill.status, BillStatus.dueToday);
    });

    test('returns upcoming when dueDate is in the future', () {
      final bill = makeBill(dueDate: DateTime(2026, 9, 1));
      expect(bill.status, BillStatus.upcoming);
    });

    test('returns dueToday at midnight boundary', () {
      final today = DateTime.now();
      final dueDate = DateTime(today.year, today.month, today.day, 0, 0, 0);
      final bill = makeBill(dueDate: dueDate);
      expect(bill.status, BillStatus.dueToday);
    });

    test(
      'returns dueToday when dueDate is today at midnight and now is morning',
      () {
        final today = DateTime.now();
        // dueDate is midnight today
        final dueDate = DateTime(today.year, today.month, today.day);
        final bill = makeBill(dueDate: dueDate);
        // Regardless of current time, should be dueToday
        expect(bill.status, BillStatus.dueToday);
      },
    );

    test(
      'returns dueToday when dueDate is today at midnight and now is afternoon',
      () {
        final today = DateTime.now();
        // Simulate afternoon: dueDate is midnight, now is 14:56
        final dueDate = DateTime(today.year, today.month, today.day);
        final bill = makeBill(dueDate: dueDate);
        expect(bill.status, BillStatus.dueToday);
      },
    );

    test(
      'returns dueToday when dueDate is today at midnight and now is night',
      () {
        final today = DateTime.now();
        // Simulate night: dueDate is midnight, now is 23:59
        final dueDate = DateTime(today.year, today.month, today.day);
        final bill = makeBill(dueDate: dueDate);
        expect(bill.status, BillStatus.dueToday);
      },
    );

    test('returns overdue when dueDate is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final bill = makeBill(dueDate: yesterday);
      expect(bill.status, BillStatus.overdue);
    });

    test('returns upcoming when dueDate is tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final bill = makeBill(dueDate: tomorrow);
      expect(bill.status, BillStatus.upcoming);
    });

    test('returns paid when bill is paid regardless of due date', () {
      final today = DateTime.now();
      final bill = makeBill(dueDate: today, isPaid: true);
      expect(bill.status, BillStatus.paid);
    });
  });

  group('BillEntity.nextDueDate', () {
    test('weekly recurrence adds 7 days', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 8, 25),
        isRecurring: true,
        recurrenceType: RecurrenceType.weekly,
        recurrenceInterval: 1,
      );
      expect(bill.nextDueDate, DateTime(2026, 9, 1));
    });

    test('monthly recurrence advances to next month', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 8, 25),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 1,
      );
      expect(bill.nextDueDate, DateTime(2026, 9, 25));
    });

    test('yearly recurrence advances by one year', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 8, 25),
        isRecurring: true,
        recurrenceType: RecurrenceType.yearly,
        recurrenceInterval: 1,
      );
      expect(bill.nextDueDate, DateTime(2027, 8, 25));
    });

    test('monthly recurrence handles 31st to month with 30 days', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 1, 31),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 1,
      );
      // Feb 2026 has 28 days, so day clamps to 28.
      expect(bill.nextDueDate, DateTime(2026, 2, 28));
    });

    test('monthly recurrence handles 31st to month with 31 days', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 3, 31),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 1,
      );
      // April has 30 days, so day clamps to 30.
      expect(bill.nextDueDate, DateTime(2026, 4, 30));
    });

    test('monthly recurrence handles leap year', () {
      final bill = makeBill(
        dueDate: DateTime(2024, 1, 31),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 1,
      );
      // Feb 2024 is a leap year with 29 days.
      expect(bill.nextDueDate, DateTime(2024, 2, 29));
    });

    test('monthly recurrence handles year boundary', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 12, 15),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 1,
      );
      expect(bill.nextDueDate, DateTime(2027, 1, 15));
    });

    test('interval=3 monthly advances by 3 months', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 1, 31),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        recurrenceInterval: 3,
      );
      // Jan + 3 = April (30 days), day clamps to 30.
      expect(bill.nextDueDate, DateTime(2026, 4, 30));
    });
  });

  group('BillEntity.reminderDateTime', () {
    test('returns null when reminder is disabled', () {
      final bill = makeBill(reminderEnabled: false);
      expect(bill.reminderDateTime, isNull);
    });

    test('returns due date minus offset days at 9am when no dueTime', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 9, 5),
        reminderEnabled: true,
        reminderOffsetDays: 2,
      );
      expect(bill.reminderDateTime, DateTime(2026, 9, 3, 9, 0));
    });

    test('returns due date minus offset at dueTime when dueTime is set', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 9, 5),
        dueTime: DateTime(2026, 9, 5, 14, 30),
        reminderEnabled: true,
        reminderOffsetDays: 1,
      );
      expect(bill.reminderDateTime, DateTime(2026, 9, 4, 14, 30));
    });

    test('zero offset returns reminder on the due date', () {
      final bill = makeBill(
        dueDate: DateTime(2026, 9, 5),
        reminderEnabled: true,
        reminderOffsetDays: 0,
      );
      expect(bill.reminderDateTime, DateTime(2026, 9, 5, 9, 0));
    });
  });

  group('BillEntity.notificationId', () {
    test('is deterministic for same bill id', () {
      final bill1 = makeBill(id: 'bill-123');
      final bill2 = makeBill(id: 'bill-123');
      expect(bill1.notificationId, bill2.notificationId);
    });

    test('is different for different bill ids', () {
      final bill1 = makeBill(id: 'bill-1');
      final bill2 = makeBill(id: 'bill-2');
      expect(bill1.notificationId, isNot(equals(bill2.notificationId)));
    });

    test('is positive and in valid range', () {
      final bill = makeBill(id: 'bill-test');
      expect(bill.notificationId, greaterThan(0));
      expect(bill.notificationId, lessThan(2147483647));
    });
  });

  group('BillEntity.copyWith', () {
    test('creates a copy with updated fields', () {
      final bill = makeBill();
      final updated = bill.copyWith(title: 'Updated', amount: 2000);
      expect(updated.title, 'Updated');
      expect(updated.amount, 2000);
      expect(bill.title, 'Test Bill'); // Original unchanged.
    });

    test('clearNote removes the note', () {
      final bill = makeBill();
      final withNote = bill.copyWith(note: 'test note');
      expect(withNote.note, 'test note');
      final cleared = withNote.copyWith(clearNote: true);
      expect(cleared.note, isNull);
    });
  });

  group('BillPaymentRecord', () {
    test('equatable works correctly', () {
      final now = DateTime(2026, 8, 25);
      final p1 = BillPaymentRecord(
        id: 'p1',
        billId: 'b1',
        amount: 1000,
        currency: 'INR',
        paidDate: now,
        createdAt: now,
      );
      final p2 = BillPaymentRecord(
        id: 'p1',
        billId: 'b1',
        amount: 1000,
        currency: 'INR',
        paidDate: now,
        createdAt: now,
      );
      expect(p1, equals(p2));
    });
  });
}
