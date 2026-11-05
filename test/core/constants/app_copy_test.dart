import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_copy.dart';
import 'package:monivo/features/bills/domain/validators/bill_validator.dart';
import 'package:monivo/features/expenses/domain/validators/expense_validator.dart';

/// UX-092: one wording for the same mistake on every form, and shared
/// terms in sentence case.
void main() {
  group('amount errors read the same everywhere', () {
    final cases = {
      '': ValidationCopy.amountEmpty,
      'abc': ValidationCopy.amountInvalid,
      '0': ValidationCopy.amountNotPositive,
      '1000000000000': ValidationCopy.amountTooLarge,
      '12.345': ValidationCopy.tooManyDecimals(2),
    };
    for (final MapEntry(key: input, value: message) in cases.entries) {
      test('"$input"', () {
        expect(
          ExpenseValidator.validateAmount(input, currency: 'INR'),
          message,
        );
        expect(BillValidator.validateAmount(input, currency: 'INR'), message);
      });
    }

    test('every message is an instruction ending in a full stop', () {
      for (final m in [
        ValidationCopy.amountEmpty,
        ValidationCopy.amountInvalid,
        ValidationCopy.amountNotPositive,
        ValidationCopy.amountTooLarge,
        ValidationCopy.tooManyDecimals(3),
        ValidationCopy.budgetNameEmpty,
        ValidationCopy.billNameEmpty,
        ValidationCopy.endBeforeStart,
      ]) {
        expect(m, endsWith('.'));
        expect(m, isNot(contains('cannot')));
        expect(m, isNot(startsWith('Please')));
      }
    });
  });

  test('domain labels show in sentence case', () {
    expect(AppTerms.sentenceCase('This Week'), 'This week');
    expect(AppTerms.sentenceCase('Newest First'), 'Newest first');
    expect(AppTerms.sentenceCase(''), '');
  });
}
