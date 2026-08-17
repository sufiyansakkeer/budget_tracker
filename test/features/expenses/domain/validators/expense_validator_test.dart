import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/validators/expense_validator.dart';

void main() {
  group('ExpenseValidator.validateAmount', () {
    test('returns error for null input', () {
      expect(ExpenseValidator.validateAmount(null), 'Amount cannot be empty');
    });

    test('returns error for empty input', () {
      expect(ExpenseValidator.validateAmount('   '), 'Amount cannot be empty');
    });

    test('returns error for non-numeric input', () {
      expect(
        ExpenseValidator.validateAmount('abc'),
        'Please enter a valid number',
      );
    });

    test('returns error for zero', () {
      expect(
        ExpenseValidator.validateAmount('0'),
        'Amount must be greater than zero',
      );
    });

    test('returns error for negative value', () {
      expect(
        ExpenseValidator.validateAmount('-5'),
        'Amount must be greater than zero',
      );
    });

    test('returns error for more than 2 decimal places', () {
      expect(
        ExpenseValidator.validateAmount('12.345'),
        'Amount cannot have more than 2 decimal places',
      );
    });

    test('returns null for valid positive amount', () {
      expect(ExpenseValidator.validateAmount('12.50'), isNull);
    });

    test('returns null for whole number', () {
      expect(ExpenseValidator.validateAmount('100'), isNull);
    });
  });

  group('ExpenseValidator.validateAmountValue', () {
    test('returns error for null', () {
      expect(
        ExpenseValidator.validateAmountValue(null),
        'Amount cannot be empty',
      );
    });

    test('returns error for zero', () {
      expect(
        ExpenseValidator.validateAmountValue(0),
        'Amount must be greater than zero',
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
        'Please select a category',
      );
    });

    test('returns error for empty category', () {
      expect(ExpenseValidator.validateCategory(''), 'Please select a category');
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
        'Please select a date',
      );
    });

    test('returns error for future date', () {
      expect(
        ExpenseValidator.validateDate(DateTime(2026, 8, 11), now: now),
        'Date cannot be in the future',
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
        'Note cannot exceed 500 characters',
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
