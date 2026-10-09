import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/validators/expense_validator.dart';
import 'package:monivo/features/expenses/presentation/quick_add/amount_entry.dart';

AmountEntry type(AmountEntry entry, String keys) {
  var e = entry;
  for (final k in keys.split('')) {
    e = switch (k) {
      '.' => e.decimal(),
      '<' => e.backspace(),
      _ => e.digit(int.parse(k)),
    };
  }
  return e;
}

void main() {
  group('INR (two decimals)', () {
    final empty = AmountEntry.empty('INR');

    test('types an amount with grouping and keeps the fraction as typed', () {
      final e = type(empty, '1250.5');
      expect(e.text, '1250.5');
      expect(e.display, '1,250.5');
      expect(e.value, 1250.5);
    });

    test('a third decimal is ignored', () {
      expect(type(empty, '9.999').text, '9.99');
    });

    test('a leading zero is replaced; "." alone starts "0."', () {
      expect(type(empty, '07').text, '7');
      expect(type(empty, '.5').text, '0.5');
      expect(type(empty, '.').display, '0.');
    });

    test('only one decimal point', () {
      expect(type(empty, '1..2.3').text, '1.23');
    });

    test('backspace and clear', () {
      expect(type(empty, '12.5<<').text, '12');
      expect(type(empty, '<').isEmpty, isTrue);
      expect(type(empty, '42').clear().isEmpty, isTrue);
    });

    test('stops at the largest whole amount the app accepts', () {
      final e = type(empty, '9999999999999');
      expect(e.text, '999999999999');
      expect(ExpenseValidator.validateAmount(e.normalized), isNull);
    });

    test('the normalized text always passes the validator once non-zero', () {
      for (final keys in ['1', '12.', '0.5', '99.99', '1000000']) {
        final e = type(empty, keys);
        expect(
          ExpenseValidator.validateAmount(e.normalized),
          isNull,
          reason: keys,
        );
      }
      expect(type(empty, '12.').normalized, '12');
    });

    test('empty shows 0 and is worth 0', () {
      expect(empty.display, '0');
      expect(empty.value, 0);
    });
  });

  test('JPY has no decimal key', () {
    final e = type(AmountEntry.empty('JPY'), '12.5');
    expect(AmountEntry.empty('JPY').allowsDecimal, isFalse);
    expect(e.text, '125');
  });

  test('OMR takes its three places (fils), never a fourth', () {
    expect(AmountEntry.empty('OMR').maxFractionDigits, 3);
    final e = type(AmountEntry.empty('OMR'), '7.1259');
    expect(e.text, '7.125');
    expect(
      ExpenseValidator.validateAmount(e.normalized, currency: 'OMR'),
      isNull,
    );
  });

  test('of() pre-fills without trailing zeros', () {
    expect(AmountEntry.of(250, 'INR').text, '250');
    expect(AmountEntry.of(250.5, 'INR').text, '250.5');
    expect(AmountEntry.of(100.1, 'INR').text, '100.1');
    expect(AmountEntry.of(120, 'JPY').text, '120');
    expect(AmountEntry.of(0, 'INR').isEmpty, isTrue);
  });

  test('forCurrency keeps the digits and drops what the new currency '
      'cannot hold', () {
    final inr = type(AmountEntry.empty('INR'), '12.75');
    expect(inr.forCurrency('JPY').text, '12');
    expect(inr.forCurrency('JPY').allowsDecimal, isFalse);
    expect(inr.forCurrency('USD'), inr);
    final jpy = type(AmountEntry.empty('JPY'), '500');
    expect(jpy.forCurrency('INR').text, '500');
    expect(jpy.forCurrency('INR').decimal().text, '500.');
  });
}
