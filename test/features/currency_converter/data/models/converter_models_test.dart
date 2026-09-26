import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/currency_converter/data/models/currency_model.dart';
import 'package:monivo/features/currency_converter/data/models/exchange_rate_model.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate.dart';

import '../../helpers/converter_fakes.dart';

void main() {
  group('ExchangeRateModel.fromJson', () {
    ExchangeRateModelParse parse(Object? json) =>
        () => ExchangeRateModel.fromJson(
          json,
          expectedBase: 'OMR',
          expectedQuote: 'INR',
          fetchedAt: testNow,
          provider: 'Frankfurter',
        );

    test('parses the real Frankfurter response exactly', () {
      final rate = parse({
        'date': '2026-09-26',
        'base': 'OMR',
        'quote': 'INR',
        'rate': 249.33,
      })();
      expect(rate.baseCurrency, 'OMR');
      expect(rate.quoteCurrency, 'INR');
      expect(rate.rate, ExactDecimal.parse('249.33'));
      expect(rate.rateDate, DateTime.utc(2026, 9, 26));
      expect(rate.fetchedAt, testNow);
      expect(rate.provider, 'Frankfurter');
      expect(rate.id, 'OMR_INR');
    });

    test('accepts integer rates and lower-case codes', () {
      final rate = parse({
        'date': '2026-09-26',
        'base': 'omr',
        'quote': 'inr',
        'rate': 249,
      })();
      expect(rate.rate.toString(), '249');
    });

    test('rejects malformed, empty or mismatched bodies', () {
      final bad = <Object?>[
        null,
        [],
        'text',
        <String, dynamic>{},
        {'date': '2026-09-26', 'base': 'OMR', 'quote': 'USD', 'rate': 2.6},
        {'date': '2026-09-26', 'base': 'OMR', 'quote': 'INR'},
        {'date': '2026-09-26', 'base': 'OMR', 'quote': 'INR', 'rate': '249'},
        {'date': '2026-09-26', 'base': 'OMR', 'quote': 'INR', 'rate': 0},
        {'date': '2026-09-26', 'base': 'OMR', 'quote': 'INR', 'rate': -1.5},
        {'date': 'yesterday', 'base': 'OMR', 'quote': 'INR', 'rate': 249.33},
        {'base': 'OMR', 'quote': 'INR', 'rate': 249.33},
      ];
      for (final json in bad) {
        expect(parse(json), throwsFormatException, reason: '$json');
      }
    });
  });

  group('ExchangeRateModel cache rows', () {
    test('round-trip keeps the rate at full precision', () {
      final rate = rateOf('INR', 'OMR', '0.0040107488068');
      final companion = ExchangeRateModel.toCompanion(rate);
      expect(companion.rate.value, '0.0040107488068');
      expect(companion.rateDate.value, '2026-09-26');
      expect(companion.id.value, 'INR_OMR');

      final row = ExchangeRateRow(
        id: companion.id.value,
        baseCurrency: companion.baseCurrency.value,
        quoteCurrency: companion.quoteCurrency.value,
        rate: companion.rate.value,
        rateDate: companion.rateDate.value,
        fetchedAt: companion.fetchedAt.value,
        provider: companion.provider.value,
      );
      expect(ExchangeRateModel.fromRow(row), rate);
    });

    test('a corrupt row reads as a cache miss', () {
      ExchangeRateRow row({
        String rate = '249.33',
        String date = '2026-09-26',
      }) => ExchangeRateRow(
        id: 'OMR_INR',
        baseCurrency: 'OMR',
        quoteCurrency: 'INR',
        rate: rate,
        rateDate: date,
        fetchedAt: testNow,
        provider: 'Frankfurter',
      );
      expect(ExchangeRateModel.fromRow(row(rate: 'abc')), isNull);
      expect(ExchangeRateModel.fromRow(row(rate: '0')), isNull);
      expect(ExchangeRateModel.fromRow(row(date: 'nope')), isNull);
      expect(ExchangeRateModel.fromRow(row()), isNotNull);
    });
  });

  group('CurrencyModel.listFromJson', () {
    test('parses the currencies endpoint and sorts by code', () {
      final list = CurrencyModel.listFromJson([
        {
          'iso_code': 'OMR',
          'iso_numeric': '512',
          'name': 'Omani Rial',
          'symbol': 'ر.ع.',
          'start_date': '1986-01-01',
          'end_date': '2026-09-26',
        },
        {'iso_code': 'CMD', 'name': 'COMESA Dollar', 'symbol': null},
        {
          'iso_code': 'AED',
          'name': 'United Arab Emirates Dirham',
          'symbol': 'د.إ',
        },
      ]);
      expect(list.map((c) => c.code), ['AED', 'CMD', 'OMR']);
      expect(list.first.name, 'United Arab Emirates Dirham');
      expect(list[1].symbol, isNull);
      expect(list[2].symbol, 'ر.ع.');
    });

    test('skips unusable entries but rejects an unusable body', () {
      final list = CurrencyModel.listFromJson([
        {'iso_code': 'US', 'name': 'bad'},
        'junk',
        {'name': 'no code'},
        {'iso_code': 'inr', 'name': ''},
      ]);
      expect(list.single.code, 'INR');
      expect(list.single.name, 'INR');

      expect(() => CurrencyModel.listFromJson([]), throwsFormatException);
      expect(() => CurrencyModel.listFromJson({'a': 1}), throwsFormatException);
      expect(
        () => CurrencyModel.listFromJson([
          {'iso_code': '1'},
        ]),
        throwsFormatException,
      );
    });
  });
}

typedef ExchangeRateModelParse = ExchangeRate Function();
