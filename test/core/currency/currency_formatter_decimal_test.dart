import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/currency/exact_decimal.dart';

ExactDecimal d(String s) => ExactDecimal.parse(s);

void main() {
  group('resolveSymbol', () {
    test('uses the app symbol for its settings currencies', () {
      expect(CurrencyFormatter.resolveSymbol('INR', providerSymbol: 'Rs'), '₹');
      expect(CurrencyFormatter.resolveSymbol('OMR'), 'ر.ع.');
      expect(
        CurrencyFormatter.resolveSymbol('aud', providerSymbol: r'$'),
        r'A$',
      );
    });

    test('uses the provider symbol for other currencies', () {
      expect(CurrencyFormatter.resolveSymbol('THB', providerSymbol: '฿'), '฿');
      expect(
        CurrencyFormatter.resolveSymbol('KWD', providerSymbol: 'د.ك'),
        'د.ك',
      );
    });

    test('never borrows a symbol an app currency owns', () {
      expect(
        CurrencyFormatter.resolveSymbol('MXN', providerSymbol: r'$'),
        r'MX$',
      );
      expect(
        CurrencyFormatter.resolveSymbol('CNY', providerSymbol: '¥'),
        'CNY',
      );
    });

    test('falls back to the code, never to ₹', () {
      expect(CurrencyFormatter.resolveSymbol('CMD'), 'CMD');
      expect(
        CurrencyFormatter.resolveSymbol('XYZ', providerSymbol: '  '),
        'XYZ',
      );
      // The legacy helper is unchanged for app-wide amounts.
      expect(CurrencyFormatter.symbolFor('XYZ'), '₹');
    });
  });

  test('decimalDigitsFor follows ISO 4217 minor units', () {
    expect(CurrencyFormatter.decimalDigitsFor('INR'), 2);
    expect(CurrencyFormatter.decimalDigitsFor('OMR'), 3);
    expect(CurrencyFormatter.decimalDigitsFor('KWD'), 3);
    expect(CurrencyFormatter.decimalDigitsFor('JPY'), 0);
    expect(CurrencyFormatter.decimalDigitsFor('usd'), 2);
  });

  group('formatDecimal', () {
    test('formats with the symbol, grouping and exact decimals', () {
      expect(
        CurrencyFormatter.formatDecimal(
          d('24933'),
          symbol: '₹',
          decimalDigits: 2,
        ),
        '₹24,933.00',
      );
      expect(
        CurrencyFormatter.formatDecimal(
          d('1234.5'),
          symbol: 'ر.ع.',
          decimalDigits: 3,
        ),
        'ر.ع.\u200E1,234.500',
      );
      expect(
        CurrencyFormatter.formatDecimal(
          d('158340'),
          symbol: '¥',
          decimalDigits: 0,
        ),
        '¥158,340',
      );
      expect(
        CurrencyFormatter.formatDecimal(
          d('-0.5'),
          symbol: r'$',
          decimalDigits: 2,
        ),
        r'-$0.50',
      );
      expect(
        CurrencyFormatter.formatDecimal(
          d('-0.001'),
          symbol: r'$',
          decimalDigits: 2,
        ),
        r'$0.00',
      );
    });

    test('keeps digits after an Arabic-script symbol in reading order', () {
      // Without the left-to-right mark the bidi algorithm renders
      // "ر.ع.1.000" as "1.000ر.ع.".
      expect(
        CurrencyFormatter.formatDecimal(
          d('1'),
          symbol: 'د.إ',
          decimalDigits: 2,
        ),
        'د.إ\u200E1.00',
      );
      // Latin-script symbols are untouched.
      expect(
        CurrencyFormatter.formatDecimal(d('1'), symbol: '₹', decimalDigits: 2),
        '₹1.00',
      );
    });

    test('stays exact beyond double and 64-bit range', () {
      expect(
        CurrencyFormatter.formatDecimal(
          d('12345678901234567890.12'),
          symbol: 'Rp',
          decimalDigits: 2,
        ),
        'Rp12,345,678,901,234,567,890.12',
      );
    });

    test('matches CurrencyFormatter.format for values a double holds', () {
      for (final value in [0.0, 1.0, 12.5, 999.99, 1234.56, 1000000.0, 0.07]) {
        expect(
          CurrencyFormatter.formatDecimal(
            ExactDecimal.fromNum(value),
            symbol: '₹',
            decimalDigits: 2,
          ),
          CurrencyFormatter.format(value, code: 'INR', decimalDigits: 2),
          reason: '$value',
        );
      }
    });
  });

  group('formatRate', () {
    test('keeps enough significant digits for small rates', () {
      final inverse = ExactDecimal.one.divide(
        d('249.33'),
        significantDigits: 12,
      );
      expect(
        CurrencyFormatter.formatRate(inverse, symbol: 'ر.ع.', code: 'OMR'),
        'ر.ع.\u200E0.00401075',
      );
    });

    test('never shows fewer decimals than the currency uses', () {
      expect(
        CurrencyFormatter.formatRate(d('249.33'), symbol: '₹', code: 'INR'),
        '₹249.33',
      );
      expect(
        CurrencyFormatter.formatRate(d('58108'), symbol: 'Rp', code: 'IDR'),
        'Rp58,108.00',
      );
      expect(
        CurrencyFormatter.formatRate(d('0.3845'), symbol: 'ر.ع.', code: 'OMR'),
        'ر.ع.\u200E0.3845',
      );
    });
  });
}
