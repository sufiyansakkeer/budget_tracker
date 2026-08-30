import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/features/expenses/domain/validators/expense_validator.dart';
import 'package:monivo/features/bills/domain/validators/bill_validator.dart';

void main() {
  group('ExpenseValidator NaN/infinity protection', () {
    test('validateAmountValue rejects NaN', () {
      expect(
        ExpenseValidator.validateAmountValue(double.nan),
        isNotNull,
      );
    });

    test('validateAmountValue rejects positive infinity', () {
      expect(
        ExpenseValidator.validateAmountValue(double.infinity),
        isNotNull,
      );
    });

    test('validateAmountValue rejects negative infinity', () {
      expect(
        ExpenseValidator.validateAmountValue(double.negativeInfinity),
        isNotNull,
      );
    });

    test('validateAmountValue rejects zero', () {
      expect(ExpenseValidator.validateAmountValue(0), isNotNull);
    });

    test('validateAmountValue rejects negative', () {
      expect(ExpenseValidator.validateAmountValue(-100), isNotNull);
    });

    test('validateAmountValue accepts valid positive amount', () {
      expect(ExpenseValidator.validateAmountValue(100.50), isNull);
    });

    test('validateAmount rejects string with NaN value', () {
      expect(
        ExpenseValidator.validateAmount('abc'),
        isNotNull,
      );
    });

    test('validateAmount rejects empty string', () {
      expect(
        ExpenseValidator.validateAmount(''),
        isNotNull,
      );
    });

    test('validateAmount rejects null', () {
      expect(
        ExpenseValidator.validateAmount(null),
        isNotNull,
      );
    });

    test('validateAmount rejects zero amount string', () {
      expect(
        ExpenseValidator.validateAmount('0'),
        isNotNull,
      );
    });

    test('validateAmount rejects negative amount string', () {
      expect(
        ExpenseValidator.validateAmount('-5'),
        isNotNull,
      );
    });

    test('validateAmount accepts valid amount string', () {
      expect(
        ExpenseValidator.validateAmount('100.50'),
        isNull,
      );
    });
  });

  group('BillValidator NaN/infinity protection', () {
    test('validateAmountValue rejects NaN', () {
      expect(
        BillValidator.validateAmountValue(double.nan),
        isNotNull,
      );
    });

    test('validateAmountValue rejects positive infinity', () {
      expect(
        BillValidator.validateAmountValue(double.infinity),
        isNotNull,
      );
    });

    test('validateAmountValue rejects negative infinity', () {
      expect(
        BillValidator.validateAmountValue(double.negativeInfinity),
        isNotNull,
      );
    });

    test('validateAmountValue rejects zero', () {
      expect(BillValidator.validateAmountValue(0), isNotNull);
    });

    test('validateAmountValue rejects negative', () {
      expect(BillValidator.validateAmountValue(-100), isNotNull);
    });

    test('validateAmountValue accepts valid positive amount', () {
      expect(BillValidator.validateAmountValue(100.50), isNull);
    });

    test('validateAmount rejects NaN string', () {
      expect(
        BillValidator.validateAmount('NaN'),
        isNotNull,
      );
    });

    test('validateAmount rejects zero amount string', () {
      expect(
        BillValidator.validateAmount('0'),
        isNotNull,
      );
    });

    test('validateAmount rejects negative amount string', () {
      expect(
        BillValidator.validateAmount('-5'),
        isNotNull,
      );
    });

    test('validateAmount accepts valid amount string', () {
      expect(
        BillValidator.validateAmount('100.50'),
        isNull,
      );
    });
  });
}
