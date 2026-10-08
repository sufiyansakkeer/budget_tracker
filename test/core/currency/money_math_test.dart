import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/money_math.dart';

void main() {
  test('scale is max(currency digits, 2)', () {
    expect(MoneyMath.forCurrency('INR').scale, 100);
    expect(MoneyMath.forCurrency('OMR').scale, 1000);
    // JPY has 0 minor units, but the forms accept 2 decimals.
    expect(MoneyMath.forCurrency('JPY').scale, 100);
  });

  test('toUnits rounds half away from zero on the decimal value', () {
    final inr = MoneyMath.forCurrency('INR');
    expect(inr.toUnits(0.145), 15);
    expect(inr.toUnits(0.29), 29);
    expect(inr.toUnits(0.1 + 0.2), 30);
    expect(inr.toUnits(-2.345), -235);
    expect(inr.toUnits(1000), 100000);
    expect(MoneyMath.forCurrency('OMR').toUnits(7.6), 7600);
    expect(MoneyMath.forCurrency('JPY').toUnits(100.5), 10050);
  });

  test('sums in units are exact', () {
    final inr = MoneyMath.forCurrency('INR');
    expect(inr.toAmount(inr.toUnits(0.1) + inr.toUnits(0.2)), 0.3);
  });

  test('toUnits rejects non-finite values', () {
    expect(
      () => MoneyMath.forCurrency('INR').toUnits(double.nan),
      throwsArgumentError,
    );
  });
  group('range (review: int.parse overflow)', () {
    test('the input limit converts exactly in every currency', () {
      expect(
        MoneyMath.forCurrency('INR').toUnits(999999999999.99),
        99999999999999,
      );
      expect(
        MoneyMath.forCurrency('OMR').toUnits(999999999999.999),
        999999999999999,
      );
    });

    test('amounts beyond 2^53 units throw ArgumentError, not '
        'FormatException', () {
      final inr = MoneyMath.forCurrency('INR');
      // 1e17 INR is 1e19 units: past 64 bits, int.parse used to throw a
      // FormatException; 1e14 INR (1e16 units) fits 64 bits but not 2^53.
      expect(() => inr.toUnits(1e17), throwsArgumentError);
      expect(() => inr.toUnits(-1e17), throwsArgumentError);
      expect(() => inr.toUnits(1e14), throwsArgumentError);
      expect(inr.toUnits(9e13), 9000000000000000);
    });

    test('sumUnits refuses a total past 2^53 units', () {
      final inr = MoneyMath.forCurrency('INR');
      expect(inr.sumUnits([0.1, 0.2, 1000]), 100030);
      expect(inr.sumUnits(const []), 0);
      expect(() => inr.sumUnits([9e13, 9e13]), throwsArgumentError);
    });

    test('isWithinLimit is the input rule: finite and below 1e12', () {
      expect(MoneyMath.isWithinLimit(999999999999.99), isTrue);
      expect(MoneyMath.isWithinLimit(1e12), isFalse);
      expect(MoneyMath.isWithinLimit(1e17), isFalse);
      expect(MoneyMath.isWithinLimit(double.infinity), isFalse);
      expect(MoneyMath.isWithinLimit(double.nan), isFalse);
    });
  });
}
