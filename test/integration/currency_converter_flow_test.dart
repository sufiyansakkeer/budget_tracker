import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/currency_converter/data/datasources/currency_local_datasource_impl.dart';
import 'package:monivo/features/currency_converter/data/repository/currency_converter_repository_impl.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate_failure.dart';
import 'package:monivo/features/currency_converter/domain/entities/rate_lookup.dart';
import 'package:monivo/features/currency_converter/domain/usecases/converter_preferences_usecases.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_exchange_rate_usecase.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_supported_currencies_usecase.dart';
import 'package:monivo/features/currency_converter/presentation/bloc/currency_converter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/currency_converter/helpers/converter_fakes.dart';
import '../helpers/in_memory_database.dart';

ExactDecimal d(String s) => ExactDecimal.parse(s);

Future<void> flush() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The converter's real object graph over one SQLite database and one
/// preferences store. Only the Frankfurter HTTP client is faked. "Restarting
/// the app" builds a brand-new graph over the same storage.
void main() {
  late AppDatabase database;
  late SharedPreferences preferences;
  late FakeCurrencyRemoteDataSource network;
  late DateTime now;
  CurrencyConverterBloc? bloc;

  Future<CurrencyConverterBloc> openConverter() async {
    await bloc?.close();
    final repository = CurrencyConverterRepositoryImpl(
      remoteDataSource: network,
      localDataSource: CurrencyLocalDataSourceImpl(
        database: database,
        sharedPreferences: preferences,
      ),
      clock: () => now,
    );
    final opened = CurrencyConverterBloc(
      getSupportedCurrencies: GetSupportedCurrenciesUseCase(
        repository: repository,
      ),
      getExchangeRate: GetExchangeRateUseCase(repository: repository),
      loadPreferences: LoadConverterPreferencesUseCase(repository: repository),
      savePreferences: SaveConverterPreferencesUseCase(repository: repository),
    )..add(const CurrencyConverterStarted());
    bloc = opened;
    await flush();
    return opened;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    database = await createInMemoryDatabase();
    now = testNow;
    network = FakeCurrencyRemoteDataSource(clock: () => now);
  });

  tearDown(() async {
    await bloc?.close();
    bloc = null;
    await database.close();
  });

  test('fresh install → cache → restart → offline → refresh → swap → '
      'restart keeps the pair', () async {
    // 1–4. Fresh install, open, OMR → INR, fetch the rate.
    var converter = await openConverter();
    expect(converter.state.source.code, 'OMR');
    expect(converter.state.target.code, 'INR');
    expect(converter.state.rate?.origin, RateOrigin.online);
    expect(network.rateCalls, ['OMR_INR']);

    // 5–8. 1, 10, 100 OMR: local maths, no further requests.
    for (final (amount, expected) in [
      ('1', '249.33'),
      ('10', '2493.3'),
      ('100', '24933'),
    ]) {
      converter.add(CurrencyConverterAmountChanged(amount));
      await flush();
      expect(converter.state.result, d(expected));
    }
    expect(network.rateCalls, ['OMR_INR']);

    // The rate itself was cached in SQLite, not a converted amount.
    final row = await database.select(database.exchangeRates).getSingle();
    expect(row.id, 'OMR_INR');
    expect(row.rate, '249.33');

    // 9–11. Close and reopen: the cached rate loads, no request.
    converter = await openConverter();
    expect(converter.state.rate?.origin, RateOrigin.cached);
    expect(converter.state.amountText, '100');
    expect(converter.state.result, d('24933'));
    expect(network.rateCalls, ['OMR_INR']);

    // 12–14. Next day, offline: the saved rate still converts.
    now = DateTime.utc(2026, 9, 27, 9);
    network.failWith = ExchangeRateFailure.noConnection;
    converter = await openConverter();
    expect(converter.state.rateStatus, RateStatus.offlineWithCachedRate);
    converter.add(const CurrencyConverterAmountChanged('3'));
    await flush();
    expect(converter.state.result, d('747.99'));

    // 15–17. Back online, refresh: the cache updates.
    network
      ..failWith = null
      ..rateDate = utcDay(2026, 9, 27)
      ..rates['OMR_INR'] = '249.80';
    converter.add(const CurrencyConverterRateRefreshed());
    await flush();
    expect(converter.state.notice, ConverterNotice.rateUpdated);
    expect(converter.state.result, d('749.4'));
    final refreshed = await database.select(database.exchangeRates).getSingle();
    expect(refreshed.rate, '249.8');
    expect(refreshed.rateDate, '2026-09-27');

    // 18–19. Swap to INR → OMR: derived from the cached pair, no request.
    final callsBeforeSwap = network.rateCalls.length;
    converter.add(const CurrencyConverterAmountChanged('2498'));
    converter.add(const CurrencyConverterSwapped());
    await flush();
    expect(converter.state.source.code, 'INR');
    expect(converter.state.target.code, 'OMR');
    expect(converter.state.rate?.derived, isTrue);
    expect(converter.state.result, d('10'));
    expect(network.rateCalls.length, callsBeforeSwap);

    // 20–22. Change currencies, restart: the pair persists.
    network.rates['USD_OMR'] = '0.3845';
    converter.add(const CurrencyConverterSourceSelected('USD'));
    await flush();
    converter = await openConverter();
    expect(converter.state.source.code, 'USD');
    expect(converter.state.target.code, 'OMR');
    expect(converter.state.amountText, '2498');
    expect(converter.state.result, d('960.481'));
  });

  test('the currency list is cached and survives going offline', () async {
    await openConverter();
    expect(network.currencyCalls, 1);
    expect(
      await database.select(database.converterCurrencies).get(),
      hasLength(4),
    );

    network.failWith = ExchangeRateFailure.noConnection;
    now = testNow.add(const Duration(days: 10));
    final converter = await openConverter();
    expect(converter.state.currencies.map((c) => c.code), contains('THB'));
    expect(converter.state.currencyListIsPartial, isFalse);
  });
}
