import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/features/currency_converter/data/repository/currency_converter_repository_impl.dart';
import 'package:monivo/features/currency_converter/domain/entities/converter_preferences.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate_failure.dart';
import 'package:monivo/features/currency_converter/domain/entities/rate_lookup.dart';
import 'package:monivo/features/currency_converter/domain/usecases/converter_preferences_usecases.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_exchange_rate_usecase.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_supported_currencies_usecase.dart';
import 'package:monivo/features/currency_converter/domain/validators/amount_input_validator.dart';
import 'package:monivo/features/currency_converter/presentation/bloc/currency_converter_bloc.dart';

import '../../helpers/converter_fakes.dart';

ExactDecimal d(String s) => ExactDecimal.parse(s);

/// Lets every queued event handler and fake future finish.
Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeCurrencyRemoteDataSource remote;
  late FakeCurrencyLocalDataSource local;
  late CurrencyConverterBloc bloc;

  CurrencyConverterBloc buildBloc() {
    final repository = CurrencyConverterRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      clock: () => testNow,
    );
    return CurrencyConverterBloc(
      getSupportedCurrencies: GetSupportedCurrenciesUseCase(
        repository: repository,
      ),
      getExchangeRate: GetExchangeRateUseCase(repository: repository),
      loadPreferences: LoadConverterPreferencesUseCase(repository: repository),
      savePreferences: SaveConverterPreferencesUseCase(repository: repository),
    );
  }

  Future<CurrencyConverterBloc> started() async {
    bloc = buildBloc()..add(const CurrencyConverterStarted());
    await flush();
    return bloc;
  }

  setUp(() {
    remote = FakeCurrencyRemoteDataSource();
    local = FakeCurrencyLocalDataSource();
  });

  tearDown(() async {
    await bloc.close();
  });

  group('initialize', () {
    test('loads currencies, restores defaults and fetches the rate', () async {
      await started();
      final s = bloc.state;

      expect(s.isRestored, isTrue);
      expect(s.currencyListStatus, CurrencyListStatus.ready);
      expect(s.currencies.map((c) => c.code), ['INR', 'OMR', 'THB', 'USD']);
      expect(s.source.code, 'OMR');
      expect(s.target.code, 'INR');
      expect(s.target.symbol, '₹');
      expect(s.amountText, '1');
      expect(s.rateStatus, RateStatus.ready);
      expect(s.rate?.origin, RateOrigin.online);
      expect(s.result, d('249.33'));
      expect(remote.rateCalls, ['OMR_INR']);
      expect(remote.currencyCalls, 1);
    });

    test('restores the last pair and amount', () async {
      local.preferences = const ConverterPreferences(
        sourceCode: 'USD',
        targetCode: 'THB',
        amountText: '20',
      );
      remote.rates['USD_THB'] = '36.5';
      await started();

      expect(bloc.state.source.code, 'USD');
      expect(bloc.state.target.code, 'THB');
      expect(bloc.state.target.symbol, '฿');
      expect(bloc.state.amountText, '20');
      expect(bloc.state.result, d('730'));
    });

    test('uses a valid cached rate without calling the API', () async {
      local.rates['OMR_INR'] = rateOf('OMR', 'INR', '249.33');
      await started();

      expect(remote.rateCalls, isEmpty);
      expect(bloc.state.rate?.origin, RateOrigin.cached);
      expect(bloc.state.result, d('249.33'));
    });

    test('calls the API when the cached rate is stale', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.00',
        rateDate: utcDay(2026, 9, 24),
        fetchedAt: DateTime.utc(2026, 9, 24, 9),
      );
      await started();

      expect(remote.rateCalls, ['OMR_INR']);
      expect(bloc.state.rate?.origin, RateOrigin.online);
      expect(bloc.state.result, d('249.33'));
    });

    test('a second Started is ignored', () async {
      await started();
      bloc.add(const CurrencyConverterStarted());
      await flush();
      expect(remote.rateCalls, ['OMR_INR']);
      expect(remote.currencyCalls, 1);
    });
  });

  group('amount', () {
    test('changes convert locally, with no further API calls', () async {
      await started();
      expect(remote.rateCalls, hasLength(1));

      for (final (text, expected) in [
        ('10', '2493.3'),
        ('50', '12466.5'),
        ('100', '24933'),
      ]) {
        bloc.add(CurrencyConverterAmountChanged(text));
        await flush();
        expect(bloc.state.result, d(expected), reason: text);
        expect(bloc.state.rateStatus, RateStatus.ready);
      }
      expect(remote.rateCalls, hasLength(1));
    });

    test('invalid input clears the result but keeps the rate', () async {
      await started();
      bloc.add(const CurrencyConverterAmountChanged(''));
      await flush();
      expect(bloc.state.amountError, AmountInputError.empty);
      expect(bloc.state.result, isNull);
      expect(bloc.state.rate, isNotNull);

      bloc.add(const CurrencyConverterAmountChanged('0'));
      await flush();
      expect(bloc.state.amountError, AmountInputError.zero);

      bloc.add(const CurrencyConverterAmountChanged('2'));
      await flush();
      expect(bloc.state.amountError, isNull);
      expect(bloc.state.result, d('498.66'));
      expect(remote.rateCalls, hasLength(1));
    });

    test('a valid amount is remembered, an invalid one is not', () async {
      await started();
      bloc.add(const CurrencyConverterAmountChanged('75'));
      await flush();
      expect(local.preferences?.amountText, '75');

      bloc.add(const CurrencyConverterAmountChanged(''));
      bloc.add(const CurrencyConverterTargetSelected('USD'));
      await flush();
      expect(local.preferences?.amountText, '75');
      expect(local.preferences?.targetCode, 'USD');
    });
  });

  group('currency selection', () {
    test('selecting a source updates it and loads that rate', () async {
      remote.rates['USD_INR'] = '87.05';
      await started();

      bloc.add(const CurrencyConverterSourceSelected('USD'));
      await flush();

      expect(bloc.state.source.code, 'USD');
      expect(bloc.state.source.name, 'US Dollar');
      expect(bloc.state.result, d('87.05'));
      expect(remote.rateCalls, ['OMR_INR', 'USD_INR']);
      expect(local.preferences?.sourceCode, 'USD');
    });

    test('selecting a target updates it and loads that rate', () async {
      remote.rates['OMR_USD'] = '2.6008';
      await started();

      bloc.add(const CurrencyConverterTargetSelected('USD'));
      await flush();

      expect(bloc.state.target.code, 'USD');
      expect(bloc.state.result, d('2.6'));
      expect(local.preferences?.targetCode, 'USD');
    });

    test('picking the other side’s currency swaps instead', () async {
      await started();
      bloc.add(const CurrencyConverterTargetSelected('OMR'));
      await flush();
      expect(bloc.state.source.code, 'INR');
      expect(bloc.state.target.code, 'OMR');
    });

    test('a slow response for an old pair is dropped', () async {
      remote.rates['OMR_USD'] = '2.6008';
      await started();

      remote.gate = Completer<void>();
      bloc.add(const CurrencyConverterTargetSelected('THB'));
      await flush();
      remote.rates['OMR_THB'] = '95.1';
      bloc.add(const CurrencyConverterTargetSelected('USD'));
      await flush();
      remote.gate!.complete();
      await flush();

      expect(bloc.state.target.code, 'USD');
      expect(bloc.state.rate?.rate.quoteCurrency, 'USD');
      expect(bloc.state.result, d('2.6'));
    });
  });

  group('swap', () {
    test(
      'swaps currencies, keeps the amount, derives the rate offline',
      () async {
        await started();
        bloc.add(const CurrencyConverterAmountChanged('24933'));
        await flush();
        bloc.add(const CurrencyConverterSwapped());
        await flush();

        final s = bloc.state;
        expect(s.source.code, 'INR');
        expect(s.target.code, 'OMR');
        expect(s.amountText, '24933');
        expect(s.swapCount, 1);
        expect(s.rate?.derived, isTrue);
        expect(s.result, d('100'));
        // Only the initial OMR → INR request ever went out.
        expect(remote.rateCalls, ['OMR_INR']);
        expect(local.preferences?.sourceCode, 'INR');
      },
    );

    test('swapping back needs no request either', () async {
      await started();
      bloc
        ..add(const CurrencyConverterSwapped())
        ..add(const CurrencyConverterSwapped());
      await flush();
      expect(bloc.state.source.code, 'OMR');
      expect(bloc.state.result, d('249.33'));
      expect(remote.rateCalls, ['OMR_INR']);
    });
  });

  group('failures', () {
    test('API failure + cache → offline with the cached result', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.00',
        rateDate: utcDay(2026, 9, 24),
        fetchedAt: DateTime.utc(2026, 9, 24, 9),
      );
      remote.failWith = ExchangeRateFailure.noConnection;
      await started();

      expect(bloc.state.rateStatus, RateStatus.offlineWithCachedRate);
      expect(bloc.state.rate?.fallbackReason, ExchangeRateFailure.noConnection);
      expect(bloc.state.result, d('248'));

      bloc.add(const CurrencyConverterAmountChanged('3'));
      await flush();
      expect(bloc.state.result, d('744'));
    });

    test('server error + cache → ready, flagged as a fallback', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.00',
        rateDate: utcDay(2026, 9, 24),
        fetchedAt: DateTime.utc(2026, 9, 24, 9),
      );
      remote.failWith = ExchangeRateFailure.serviceUnavailable;
      await started();
      expect(bloc.state.rateStatus, RateStatus.ready);
      expect(bloc.state.rate?.isFallback, isTrue);
    });

    test('API failure + no cache → error, and retry recovers', () async {
      remote.failWith = ExchangeRateFailure.noConnection;
      await started();

      expect(bloc.state.rateStatus, RateStatus.error);
      expect(bloc.state.rateFailure, ExchangeRateFailure.noConnection);
      expect(bloc.state.result, isNull);
      expect(bloc.state.currencyListIsPartial, isTrue);

      remote.failWith = null;
      bloc.add(const CurrencyConverterRetried());
      await flush();

      expect(bloc.state.rateStatus, RateStatus.ready);
      expect(bloc.state.result, d('249.33'));
      expect(bloc.state.currencyListIsPartial, isFalse);
    });
  });

  group('refresh', () {
    test('updates the cached rate and says so', () async {
      await started();
      remote.rates['OMR_INR'] = '250.10';
      bloc.add(const CurrencyConverterRateRefreshed());
      await flush();

      expect(remote.rateCalls, ['OMR_INR', 'OMR_INR']);
      expect(bloc.state.result, d('250.1'));
      expect(bloc.state.isRefreshing, isFalse);
      expect(bloc.state.notice, ConverterNotice.rateUpdated);
      expect(local.rates['OMR_INR']?.rate, d('250.10'));

      bloc.add(const CurrencyConverterNoticeCleared());
      await flush();
      expect(bloc.state.notice, isNull);
    });

    test('a failed refresh keeps the saved rate', () async {
      await started();
      remote.failWith = ExchangeRateFailure.noConnection;
      bloc.add(const CurrencyConverterRateRefreshed());
      await flush();

      expect(bloc.state.result, d('249.33'));
      expect(bloc.state.rate, isNotNull);
      expect(bloc.state.notice, ConverterNotice.refreshFailedUsingSaved);
      expect(local.rates['OMR_INR']?.rate, d('249.33'));
    });

    test('repeated taps while refreshing send one request', () async {
      await started();
      remote.gate = Completer<void>();
      bloc
        ..add(const CurrencyConverterRateRefreshed())
        ..add(const CurrencyConverterRateRefreshed())
        ..add(const CurrencyConverterRateRefreshed());
      await flush();
      expect(bloc.state.isRefreshing, isTrue);
      remote.gate!.complete();
      await flush();
      expect(remote.rateCalls, ['OMR_INR', 'OMR_INR']);
    });
  });
}
