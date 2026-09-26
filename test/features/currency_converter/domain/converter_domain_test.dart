import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/features/currency_converter/domain/services/exchange_rate_freshness_policy.dart';
import 'package:monivo/features/currency_converter/domain/usecases/convert_amount_usecase.dart';
import 'package:monivo/features/currency_converter/domain/validators/amount_input_validator.dart';

import '../helpers/converter_fakes.dart';

ExactDecimal d(String s) => ExactDecimal.parse(s);

void main() {
  group('ExchangeRateFreshnessPolicy', () {
    const policy = ExchangeRateFreshnessPolicy();

    test("a rate for today's reference day is fresh", () {
      final rate = rateOf(
        'OMR',
        'INR',
        '249.33',
        rateDate: utcDay(2026, 9, 26),
        fetchedAt: DateTime.utc(2026, 9, 26, 1),
      );
      expect(policy.isFresh(rate, DateTime.utc(2026, 9, 26, 23, 59)), isTrue);
    });

    test('it goes stale once the next UTC day starts', () {
      final rate = rateOf(
        'OMR',
        'INR',
        '249.33',
        rateDate: utcDay(2026, 9, 26),
        fetchedAt: DateTime.utc(2026, 9, 26, 12),
      );
      expect(policy.isFresh(rate, DateTime.utc(2026, 9, 27, 0, 1)), isFalse);
    });

    test('an older reference day stays fresh briefly after a fetch', () {
      // Weekend/holiday: the provider's latest is yesterday's rate.
      final rate = rateOf(
        'KWD',
        'IDR',
        '58108',
        rateDate: utcDay(2026, 9, 25),
        fetchedAt: DateTime.utc(2026, 9, 26, 10),
      );
      expect(policy.isFresh(rate, DateTime.utc(2026, 9, 26, 15)), isTrue);
      expect(policy.isFresh(rate, DateTime.utc(2026, 9, 26, 16, 1)), isFalse);
    });

    test('a fetch time in the future is not trusted', () {
      final rate = rateOf(
        'OMR',
        'INR',
        '249.33',
        rateDate: utcDay(2026, 9, 20),
        fetchedAt: DateTime.utc(2027, 1, 1),
      );
      expect(policy.isFresh(rate, testNow), isFalse);
    });

    test('works with local-time clocks too', () {
      final rate = rateOf(
        'OMR',
        'INR',
        '249.33',
        rateDate: utcDay(2026, 9, 26),
      );
      final localNow = DateTime.utc(2026, 9, 26, 12).toLocal();
      expect(policy.isFresh(rate, localNow), isTrue);
    });
  });

  group('ConvertAmountUseCase', () {
    const convert = ConvertAmountUseCase();
    final omrInr = rateOf('OMR', 'INR', '249.33');

    test('1 OMR at X gives exactly X INR', () {
      expect(
        convert(amount: d('1'), rate: omrInr, targetDecimalDigits: 2),
        d('249.33'),
      );
    });

    test('10, 50 and 100 OMR multiply exactly', () {
      for (final (amount, expected) in [
        ('10', '2493.3'),
        ('50', '12466.5'),
        ('100', '24933'),
        ('250', '62332.5'),
      ]) {
        expect(
          convert(amount: d(amount), rate: omrInr, targetDecimalDigits: 2),
          d(expected),
          reason: amount,
        );
      }
    });

    test('rounds once, half away from zero, to the target decimals', () {
      // 1.005 × 1 would be 1.00 with double rounding (1.00499999...).
      final one = rateOf('USD', 'EUR', '1');
      expect(
        convert(amount: d('1.005'), rate: one, targetDecimalDigits: 2),
        d('1.01'),
      );
      // JPY has no minor unit.
      expect(
        convert(
          amount: d('10'),
          rate: rateOf('USD', 'JPY', '158.34'),
          targetDecimalDigits: 0,
        ),
        d('1583'),
      );
      // OMR has three decimals.
      expect(
        convert(
          amount: d('100'),
          rate: rateOf('USD', 'OMR', '0.3845'),
          targetDecimalDigits: 3,
        ),
        d('38.45'),
      );
    });

    test('reverse conversion uses the full-precision inverse', () {
      final inrOmr = omrInr.inverted();
      // 24,933 INR must come back to exactly 100 OMR.
      expect(
        convert(amount: d('24933'), rate: inrOmr, targetDecimalDigits: 3),
        d('100'),
      );
      // The provider's own rounded 0.00401 would give 99.981.
      expect(
        convert(
          amount: d('24933'),
          rate: rateOf('INR', 'OMR', '0.00401'),
          targetDecimalDigits: 3,
        ),
        d('99.981'),
      );
    });
  });

  group('AmountInputValidator', () {
    const validator = AmountInputValidator();

    AmountInputError? errorOf(String s) => validator.validate(s).error;

    test('accepts integers and decimals', () {
      expect(validator.validate('1').value, d('1'));
      expect(validator.validate('12.50').value, d('12.5'));
      expect(validator.validate('.5').value, d('0.5'));
      expect(validator.validate('12.').value, d('12'));
      expect(validator.validate(' 1 000 ').value, d('1000'));
      expect(validator.validate('2,75').value, d('2.75'));
    });

    test('empty', () {
      expect(errorOf(''), AmountInputError.empty);
      expect(errorOf('   '), AmountInputError.empty);
      expect(AmountInputError.empty.message, 'Enter an amount');
    });

    test('zero', () {
      expect(errorOf('0'), AmountInputError.zero);
      expect(errorOf('0.000'), AmountInputError.zero);
      expect(AmountInputError.zero.message, 'Enter an amount greater than 0');
    });

    test('negative', () {
      expect(errorOf('-5'), AmountInputError.negative);
    });

    test('very large', () {
      expect(errorOf('999999999999.99'), isNull);
      expect(errorOf('1000000000000'), AmountInputError.tooLarge);
      expect(errorOf('99999999999999999999'), AmountInputError.tooLarge);
    });

    test('invalid characters never crash', () {
      for (final bad in [
        'abc',
        '1.2.3',
        '1e5',
        '--1',
        '12a',
        '.',
        '1..2',
        '₹5',
      ]) {
        expect(errorOf(bad), AmountInputError.invalid, reason: bad);
      }
    });

    test('too many decimals', () {
      expect(errorOf('1.12345678'), isNull);
      expect(errorOf('1.123456789'), AmountInputError.tooManyDecimals);
    });
  });
}
