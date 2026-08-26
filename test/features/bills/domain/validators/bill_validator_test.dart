import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/bills/domain/validators/bill_validator.dart';

void main() {
  group('BillValidator.validateTitle', () {
    test('returns error for null input', () {
      expect(BillValidator.validateTitle(null), isNotNull);
    });

    test('returns error for empty input', () {
      expect(BillValidator.validateTitle(''), isNotNull);
    });

    test('returns error for whitespace-only input', () {
      expect(BillValidator.validateTitle('   '), isNotNull);
    });

    test('returns null for valid title', () {
      expect(BillValidator.validateTitle('Rent'), isNull);
    });

    test('returns error for title exceeding max length', () {
      expect(BillValidator.validateTitle('A' * 101), isNotNull);
    });

    test('returns null for title at max length', () {
      expect(BillValidator.validateTitle('A' * 100), isNull);
    });
  });

  group('BillValidator.validateAmount', () {
    test('returns error for null input', () {
      expect(BillValidator.validateAmount(null), isNotNull);
    });

    test('returns error for empty input', () {
      expect(BillValidator.validateAmount(''), isNotNull);
    });

    test('returns error for non-numeric input', () {
      expect(BillValidator.validateAmount('abc'), isNotNull);
    });

    test('returns error for zero amount', () {
      expect(BillValidator.validateAmount('0'), isNotNull);
    });

    test('returns error for negative amount', () {
      expect(BillValidator.validateAmount('-100'), isNotNull);
    });

    test('returns error for more than 2 decimal places', () {
      expect(BillValidator.validateAmount('10.999'), isNotNull);
    });

    test('returns null for valid amount', () {
      expect(BillValidator.validateAmount('1000'), isNull);
    });

    test('returns null for valid decimal amount', () {
      expect(BillValidator.validateAmount('10.99'), isNull);
    });
  });

  group('BillValidator.validateAmountValue', () {
    test('returns error for null', () {
      expect(BillValidator.validateAmountValue(null), isNotNull);
    });

    test('returns error for zero', () {
      expect(BillValidator.validateAmountValue(0), isNotNull);
    });

    test('returns error for negative', () {
      expect(BillValidator.validateAmountValue(-100), isNotNull);
    });

    test('returns null for valid amount', () {
      expect(BillValidator.validateAmountValue(1000), isNull);
    });
  });

  group('BillValidator.validateDueDate', () {
    test('returns error for null date', () {
      expect(BillValidator.validateDueDate(null), isNotNull);
    });

    test('returns null for any valid date (including past dates)', () {
      expect(BillValidator.validateDueDate(DateTime(2020, 1, 1)), isNull);
    });
  });

  group('BillValidator.validateNote', () {
    test('returns null for null note', () {
      expect(BillValidator.validateNote(null), isNull);
    });

    test('returns null for empty note', () {
      expect(BillValidator.validateNote(''), isNull);
    });

    test('returns error for note exceeding max length', () {
      expect(BillValidator.validateNote('A' * 501), isNotNull);
    });

    test('returns null for valid note', () {
      expect(BillValidator.validateNote('Some note'), isNull);
    });
  });

  group('BillValidator.validateRecurrence', () {
    test('returns null when not recurring', () {
      expect(
        BillValidator.validateRecurrence(
          isRecurring: false,
          recurrenceInterval: 1,
        ),
        isNull,
      );
    });

    test('returns error for interval < 1', () {
      expect(
        BillValidator.validateRecurrence(
          isRecurring: true,
          recurrenceInterval: 0,
        ),
        isNotNull,
      );
    });

    test('returns null for valid recurring settings', () {
      expect(
        BillValidator.validateRecurrence(
          isRecurring: true,
          recurrenceInterval: 3,
        ),
        isNull,
      );
    });
  });

  group('BillValidator.validateReminderOffset', () {
    test('returns error for negative offset', () {
      expect(BillValidator.validateReminderOffset(-1), isNotNull);
    });

    test('returns null for zero offset', () {
      expect(BillValidator.validateReminderOffset(0), isNull);
    });

    test('returns null for valid offset', () {
      expect(BillValidator.validateReminderOffset(7), isNull);
    });
  });
}
