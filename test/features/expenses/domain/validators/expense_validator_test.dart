import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/validators/expense_validator.dart';
import 'package:monivo/core/constants/app_copy.dart';

void main() {
  group('ExpenseValidator.validateAmount', () {
    test('rejects amounts at or above the 1e12 limit (review: overflow)', () {
      expect(
        ExpenseValidator.validateAmount('100000000000000000'),
        ValidationCopy.amountTooLarge,
      );
      expect(
        ExpenseValidator.validateAmount('1000000000000'),
        ValidationCopy.amountTooLarge,
      );
      expect(ExpenseValidator.validateAmount('999999999999.99'), isNull);
      expect(
        ExpenseValidator.validateAmountValue(1e17),
        ValidationCopy.amountTooLarge,
      );
    });

    test('returns error for null input', () {
      expect(ExpenseValidator.validateAmount(null), ValidationCopy.amountEmpty);
    });

    test('returns error for empty input', () {
      expect(
        ExpenseValidator.validateAmount('   '),
        ValidationCopy.amountEmpty,
      );
    });

    test('returns error for non-numeric input', () {
      expect(
        ExpenseValidator.validateAmount('abc'),
        ValidationCopy.amountInvalid,
      );
    });

    test('returns error for zero', () {
      expect(
        ExpenseValidator.validateAmount('0'),
        ValidationCopy.amountNotPositive,
      );
    });

    test('returns error for negative value', () {
      expect(
        ExpenseValidator.validateAmount('-5'),
        ValidationCopy.amountNotPositive,
      );
    });

    test('returns error for more than 2 decimal places', () {
      expect(
        ExpenseValidator.validateAmount('12.345'),
        ValidationCopy.tooManyDecimals(2),
      );
    });

    test('returns null for valid positive amount', () {
      expect(ExpenseValidator.validateAmount('12.50'), isNull);
    });

    test('OMR takes three decimal places (fils), not four', () {
      expect(ExpenseValidator.validateAmount('7.125', currency: 'OMR'), isNull);
      expect(
        ExpenseValidator.validateAmount('7.1255', currency: 'OMR'),
        ValidationCopy.tooManyDecimals(3),
      );
      // Rupees still stop at paise; yen keep the two places they had.
      expect(
        ExpenseValidator.validateAmount('7.125', currency: 'INR'),
        ValidationCopy.tooManyDecimals(2),
      );
      expect(ExpenseValidator.validateAmount('120.5', currency: 'JPY'), isNull);
    });

    test('returns null for whole number', () {
      expect(ExpenseValidator.validateAmount('100'), isNull);
    });
  });

  group('ExpenseValidator.validateAmountValue', () {
    test('returns error for null', () {
      expect(
        ExpenseValidator.validateAmountValue(null),
        ValidationCopy.amountEmpty,
      );
    });

    test('returns error for zero', () {
      expect(
        ExpenseValidator.validateAmountValue(0),
        ValidationCopy.amountNotPositive,
      );
    });

    test('returns null for positive value', () {
      expect(ExpenseValidator.validateAmountValue(25.5), isNull);
    });
  });

  group('ExpenseValidator.validateCategory', () {
    test('returns error for null category', () {
      expect(
        ExpenseValidator.validateCategory(null),
        ValidationCopy.categoryMissing,
      );
    });

    test('returns error for empty category', () {
      expect(
        ExpenseValidator.validateCategory(''),
        ValidationCopy.categoryMissing,
      );
    });

    test('returns null for valid category', () {
      expect(ExpenseValidator.validateCategory('food'), isNull);
    });
  });

  group('ExpenseValidator.validateDate', () {
    final now = DateTime(2026, 8, 10);

    test('returns error for null date', () {
      expect(
        ExpenseValidator.validateDate(null, now: now),
        ValidationCopy.dateMissing,
      );
    });

    test('returns error for future date', () {
      expect(
        ExpenseValidator.validateDate(DateTime(2026, 8, 11), now: now),
        ValidationCopy.dateInFuture,
      );
    });

    test('returns null for today', () {
      expect(
        ExpenseValidator.validateDate(DateTime(2026, 8, 10), now: now),
        isNull,
      );
    });

    test('returns null for past date', () {
      expect(
        ExpenseValidator.validateDate(DateTime(2026, 8, 9), now: now),
        isNull,
      );
    });
  });

  group('ExpenseValidator.validateNote', () {
    test('returns null for empty note', () {
      expect(ExpenseValidator.validateNote(''), isNull);
    });

    test('returns null for null note', () {
      expect(ExpenseValidator.validateNote(null), isNull);
    });

    test('returns error for note longer than 500 chars', () {
      final longNote = 'a' * 501;
      expect(
        ExpenseValidator.validateNote(longNote),
        ValidationCopy.noteTooLong(500),
      );
    });

    test('returns null for note at max length', () {
      expect(ExpenseValidator.validateNote('a' * 500), isNull);
    });
  });

  group('ExpenseValidator.validateReceiptPath', () {
    test('returns null for null path', () {
      expect(ExpenseValidator.validateReceiptPath(null), isNull);
    });

    test('returns null for empty path', () {
      expect(ExpenseValidator.validateReceiptPath(''), isNull);
    });

    test('returns error for whitespace path', () {
      expect(
        ExpenseValidator.validateReceiptPath('   '),
        'Invalid receipt path',
      );
    });

    test('returns null for valid path', () {
      expect(
        ExpenseValidator.validateReceiptPath('/path/to/receipt.jpg'),
        isNull,
      );
    });
  });

  group('ExpenseValidator.validateTags', () {
    test('returns null for empty tags', () {
      expect(ExpenseValidator.validateTags(const []), isNull);
    });

    test('returns null for up to 10 tags', () {
      expect(
        ExpenseValidator.validateTags(List.generate(10, (i) => 't$i')),
        isNull,
      );
    });

    test('returns error for more than 10 tags', () {
      expect(
        ExpenseValidator.validateTags(List.generate(11, (i) => 't$i')),
        'Cannot add more than 10 tags',
      );
    });
  });
}
