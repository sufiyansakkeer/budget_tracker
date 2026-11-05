import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/money_input.dart';
import 'package:monivo/core/constants/app_copy.dart';

void main() {
  test('allows each currency its minor units, never fewer than two', () {
    expect(MoneyInput.maxDecimals('OMR'), 3);
    expect(MoneyInput.maxDecimals('INR'), 2);
    expect(MoneyInput.maxDecimals('JPY'), 2);
    expect(MoneyInput.maxDecimals(null), 2);
  });

  test('the pad offers only what the currency uses', () {
    expect(MoneyInput.padDecimals('OMR'), 3);
    expect(MoneyInput.padDecimals('INR'), 2);
    expect(MoneyInput.padDecimals('JPY'), 0);
  });

  test('decimals beyond the currency are refused with the count', () {
    expect(MoneyInput.decimalsError('7.125', 'OMR'), isNull);
    expect(
      MoneyInput.decimalsError('7.1255', 'OMR'),
      ValidationCopy.tooManyDecimals(3),
    );
    expect(
      MoneyInput.decimalsError('7.125', 'INR'),
      ValidationCopy.tooManyDecimals(2),
    );
    expect(
      MoneyInput.decimalsError('7.125', null),
      ValidationCopy.tooManyDecimals(2),
    );
    // UX-092: one wording on every form, read as an instruction.
    expect(ValidationCopy.tooManyDecimals(3), 'Use up to 3 decimal places.');
    expect(MoneyInput.decimalsError('12', 'OMR'), isNull);
  });

  test('the typing pattern stops at the allowed decimals', () {
    final omr = MoneyInput.pattern(3);
    expect(omr.stringMatch('7.1259'), '7.125');
    expect(MoneyInput.pattern(2).stringMatch('7.125'), '7.12');
    expect(MoneyInput.pattern(0).stringMatch('7.5'), '7');
  });

  test('editing text keeps every saved decimal and adds none', () {
    expect(MoneyInput.forInput(250), '250');
    expect(MoneyInput.forInput(12.5), '12.5');
    expect(MoneyInput.forInput(249.99), '249.99');
    expect(MoneyInput.forInput(7.125), '7.125');
    expect(MoneyInput.forInput(0.1 + 0.2), '0.3');
    expect(MoneyInput.forInput(100.10), '100.1');
  });
}
