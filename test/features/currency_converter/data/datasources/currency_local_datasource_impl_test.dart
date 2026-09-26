import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/preference_keys.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/currency_converter/data/datasources/currency_local_datasource_impl.dart';
import 'package:monivo/features/currency_converter/data/models/currency_model.dart';
import 'package:monivo/features/currency_converter/domain/entities/converter_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';
import '../../helpers/converter_fakes.dart';

void main() {
  late AppDatabase database;
  late SharedPreferences preferences;
  late CurrencyLocalDataSourceImpl source;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    database = await createInMemoryDatabase();
    source = CurrencyLocalDataSourceImpl(
      database: database,
      sharedPreferences: preferences,
    );
  });

  tearDown(() => database.close());

  group('rates', () {
    test('write then read keeps every field and full precision', () async {
      final rate = rateOf('INR', 'OMR', '0.0040107488068');
      await source.saveRate(rate);

      final read = await source.getRate('INR', 'OMR');
      expect(read!.rate, ExactDecimal.parse('0.0040107488068'));
      expect(read.baseCurrency, 'INR');
      expect(read.quoteCurrency, 'OMR');
      expect(read.rateDate, rate.rateDate);
      expect(read.provider, 'Frankfurter');
      // Drift reads DateTime back in local time: same instant.
      expect(read.fetchedAt.isAtSameMomentAs(rate.fetchedAt), isTrue);

      final row = await database.select(database.exchangeRates).getSingle();
      expect(row.id, 'INR_OMR');
      expect(row.rate, '0.0040107488068');
      expect(row.rateDate, '2026-09-26');
      expect(row.provider, 'Frankfurter');
    });

    test('keys are per direction', () async {
      await source.saveRate(rateOf('OMR', 'INR', '249.33'));
      expect(await source.getRate('INR', 'OMR'), isNull);
      expect(await source.getRate('OMR', 'USD'), isNull);
    });

    test('saving a pair again replaces it', () async {
      await source.saveRate(rateOf('OMR', 'INR', '248.00'));
      await source.saveRate(
        rateOf('OMR', 'INR', '249.33', rateDate: utcDay(2026, 9, 27)),
      );
      final rows = await database.select(database.exchangeRates).get();
      expect(rows, hasLength(1));
      expect(rows.single.rate, '249.33');
      expect(rows.single.rateDate, '2026-09-27');
    });

    test('rate cache writes leave user data untouched', () async {
      final before = await database.select(database.categories).get();
      await source.saveRate(rateOf('OMR', 'INR', '249.33'));
      expect(await database.select(database.categories).get(), before);
    });
  });

  group('currencies', () {
    test('empty cache reads as null', () async {
      expect(await source.getCurrencies(), isNull);
    });

    test('saves and reads back a list, replacing the previous one', () async {
      await source.saveCurrencies(const [
        CurrencyModel(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.'),
        CurrencyModel(code: 'CMD', name: 'COMESA Dollar'),
      ], testNow);
      await source.saveCurrencies(const [
        CurrencyModel(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
        CurrencyModel(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.'),
      ], testNow.add(const Duration(days: 1)));

      final cached = await source.getCurrencies();
      expect(cached!.currencies.map((c) => c.code), ['INR', 'OMR']);
      expect(
        cached.fetchedAt.isAtSameMomentAs(testNow.add(const Duration(days: 1))),
        isTrue,
      );
    });

    test('keeps a missing symbol as null', () async {
      await source.saveCurrencies(const [
        CurrencyModel(code: 'CMD', name: 'COMESA Dollar'),
      ], testNow);
      final cached = await source.getCurrencies();
      expect(cached!.currencies.single.symbol, isNull);
    });
  });

  group('preferences', () {
    test('null until saved', () async {
      expect(await source.getPreferences(), isNull);
    });

    test('persist the pair and amount under PreferenceKeys', () async {
      await source.savePreferences(
        const ConverterPreferences(
          sourceCode: 'USD',
          targetCode: 'INR',
          amountText: '12.5',
        ),
      );
      expect(
        preferences.getString(PreferenceKeys.converterSourceCurrency),
        'USD',
      );
      expect(
        preferences.getString(PreferenceKeys.converterTargetCurrency),
        'INR',
      );
      expect(preferences.getString(PreferenceKeys.converterAmount), '12.5');
      expect(
        await source.getPreferences(),
        const ConverterPreferences(
          sourceCode: 'USD',
          targetCode: 'INR',
          amountText: '12.5',
        ),
      );
    });
  });
}
