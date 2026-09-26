import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/exact_decimal.dart';

ExactDecimal d(String s) => ExactDecimal.parse(s);

void main() {
  group('parse', () {
    test('reads plain, signed, fractional and exponent forms', () {
      expect(d('249.33').toString(), '249.33');
      expect(d('-0.5').toString(), '-0.5');
      expect(d('.5').toString(), '0.5');
      expect(d('12.').toString(), '12');
      expect(d('1e-7').toString(), '0.0000001');
      expect(d('2.5E3').toString(), '2500');
      expect(d('58108.0').toString(), '58108');
    });

    test('rejects anything that is not a number', () {
      for (final bad in ['', '.', '-', 'abc', '1.2.3', '1,5', '1e', '--1']) {
        expect(ExactDecimal.tryParse(bad), isNull, reason: bad);
      }
      expect(() => d('x'), throwsFormatException);
    });

    test('normalises, so equality is numeric', () {
      expect(d('1.50'), d('1.5'));
      expect(d('0.000'), ExactDecimal.zero);
      expect(d('1.50').scale, 1);
    });

    test('fromNum keeps the decimal the JSON had, not binary noise', () {
      expect(ExactDecimal.fromNum(249.33).toString(), '249.33');
      expect(ExactDecimal.fromNum(0.00401).toString(), '0.00401');
      expect(ExactDecimal.fromNum(58108).toString(), '58108');
      expect(ExactDecimal.fromNum(0.1).toString(), '0.1');
      expect(() => ExactDecimal.fromNum(double.nan), throwsArgumentError);
    });
  });

  group('arithmetic', () {
    test('multiplication is exact where double is not', () {
      // 0.1 * 3 in double is 0.30000000000000004.
      expect(d('0.1') * d('3'), d('0.3'));
      expect((d('100') * d('249.33')).toString(), '24933');
      expect((d('1.005') * d('1000')).toString(), '1005');
    });

    test('divide rounds to the requested significant digits', () {
      final inverse = ExactDecimal.one.divide(
        d('249.33'),
        significantDigits: 12,
      );
      expect(inverse.toString(), '0.0040107488068');
      expect(
        ExactDecimal.one.divide(d('3'), significantDigits: 5).toString(),
        '0.33333',
      );
      expect(d('2').divide(d('3'), significantDigits: 4).toString(), '0.6667');
      expect(d('-1').divide(d('4')).toString(), '-0.25');
      expect(d('1000000').divide(d('0.5')).toString(), '2000000');
      expect(() => d('1').divide(ExactDecimal.zero), throwsArgumentError);
    });

    test('compares across scales', () {
      expect(d('1.10') > d('1.09'), isTrue);
      expect(d('0.9') < ExactDecimal.one, isTrue);
      expect(d('1.000') >= ExactDecimal.one, isTrue);
      expect(d('-2') < d('-1.5'), isTrue);
    });
  });

  group('rounding', () {
    test('roundToScale rounds half away from zero', () {
      expect(d('2.345').roundToScale(2).toString(), '2.35');
      expect(d('2.344').roundToScale(2).toString(), '2.34');
      expect(d('-2.345').roundToScale(2).toString(), '-2.35');
      expect(d('0.0005').roundToScale(3).toString(), '0.001');
      expect(d('2.5').roundToScale(0).toString(), '3');
      expect(d('1.2').roundToScale(4), d('1.2'));
    });

    test('toStringAsFixed pads and never uses exponents', () {
      expect(d('249.33').toStringAsFixed(3), '249.330');
      expect(d('0.004').toStringAsFixed(2), '0.00');
      expect(d('0.0000001').toStringAsFixed(7), '0.0000001');
      expect(d('-0.5').toStringAsFixed(0), '-1');
      expect(d('12').toStringAsFixed(0), '12');
    });

    test('toSignificantDigits trims fractions but never integer digits', () {
      expect(
        d('0.00401074880680').toSignificantDigits(6).toString(),
        '0.00401075',
      );
      expect(d('249.33').toSignificantDigits(6).toString(), '249.33');
      expect(d('58108.456').toSignificantDigits(3).toString(), '58108');
      expect(d('1.139949').toSignificantDigits(5).toString(), '1.1399');
    });

    test('absIntegerPart and toDouble', () {
      expect(d('-12.7').absIntegerPart, BigInt.from(12));
      expect(d('249.33').toDouble(), 249.33);
    });
  });
}
