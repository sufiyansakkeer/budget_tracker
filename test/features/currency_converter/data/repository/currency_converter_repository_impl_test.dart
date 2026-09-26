import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/features/currency_converter/data/datasources/currency_local_datasource.dart';
import 'package:monivo/features/currency_converter/data/models/currency_model.dart';
import 'package:monivo/features/currency_converter/data/repository/currency_converter_repository_impl.dart';
import 'package:monivo/features/currency_converter/domain/entities/converter_preferences.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate_failure.dart';
import 'package:monivo/features/currency_converter/domain/entities/rate_lookup.dart';

import '../../helpers/converter_fakes.dart';

void main() {
  late FakeCurrencyRemoteDataSource remote;
  late FakeCurrencyLocalDataSource local;
  late DateTime now;
  late CurrencyConverterRepositoryImpl repository;

  setUp(() {
    now = testNow;
    remote = FakeCurrencyRemoteDataSource(clock: () => now);
    local = FakeCurrencyLocalDataSource();
    repository = CurrencyConverterRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      clock: () => now,
    );
  });

  group('getRate', () {
    test(
      'CACHE HIT: a fresh cached rate is returned with no API call',
      () async {
        local.rates['OMR_INR'] = rateOf('OMR', 'INR', '249.33');

        final lookup = await repository.getRate('OMR', 'INR');

        expect(remote.rateCalls, isEmpty);
        expect(lookup.origin, RateOrigin.cached);
        expect(lookup.derived, isFalse);
        expect(lookup.isFallback, isFalse);
        expect(lookup.rate.rate, ExactDecimal.parse('249.33'));
      },
    );

    test('CACHE MISS: fetches, saves the rate and returns it', () async {
      final lookup = await repository.getRate('OMR', 'INR');

      expect(remote.rateCalls, ['OMR_INR']);
      expect(lookup.origin, RateOrigin.online);
      expect(lookup.rate.rate, ExactDecimal.parse('249.33'));
      expect(local.rates['OMR_INR']?.rate, ExactDecimal.parse('249.33'));
      expect(local.rates['OMR_INR']?.fetchedAt, now);
    });

    test('repeated lookups after a miss stay local', () async {
      await repository.getRate('OMR', 'INR');
      await repository.getRate('OMR', 'INR');
      await repository.getRate('omr', 'inr');
      expect(remote.rateCalls, ['OMR_INR']);
    });

    test(
      'STALE CACHE: an older rate triggers a fetch and is replaced',
      () async {
        local.rates['OMR_INR'] = rateOf(
          'OMR',
          'INR',
          '248.10',
          rateDate: utcDay(2026, 9, 24),
          fetchedAt: DateTime.utc(2026, 9, 24, 9),
        );

        final lookup = await repository.getRate('OMR', 'INR');

        expect(remote.rateCalls, ['OMR_INR']);
        expect(lookup.origin, RateOrigin.online);
        expect(lookup.rate.rate, ExactDecimal.parse('249.33'));
        expect(local.rates['OMR_INR']?.rateDate, utcDay(2026, 9, 26));
      },
    );

    test('OFFLINE: a stale rate is returned when the API fails', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.10',
        rateDate: utcDay(2026, 9, 24),
        fetchedAt: DateTime.utc(2026, 9, 24, 9),
      );
      remote.failWith = ExchangeRateFailure.noConnection;

      final lookup = await repository.getRate('OMR', 'INR');

      expect(remote.rateCalls, ['OMR_INR']);
      expect(lookup.origin, RateOrigin.cached);
      expect(lookup.fallbackReason, ExchangeRateFailure.noConnection);
      expect(lookup.rate.rate, ExactDecimal.parse('248.10'));
      // The saved rate is kept, not cleared.
      expect(local.rates['OMR_INR']?.rate, ExactDecimal.parse('248.10'));
    });

    test('NO CACHE + OFFLINE: throws a meaningful failure', () async {
      remote.failWith = ExchangeRateFailure.noConnection;
      await expectLater(
        repository.getRate('OMR', 'INR'),
        throwsA(
          isA<ExchangeRateException>().having(
            (e) => e.failure,
            'failure',
            ExchangeRateFailure.noConnection,
          ),
        ),
      );
    });

    test('API failure (server error) falls back to the cache', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.10',
        rateDate: utcDay(2026, 9, 25),
        fetchedAt: DateTime.utc(2026, 9, 25, 9),
      );
      remote.failWith = ExchangeRateFailure.serviceUnavailable;
      final lookup = await repository.getRate('OMR', 'INR');
      expect(lookup.fallbackReason, ExchangeRateFailure.serviceUnavailable);
      expect(lookup.rate.rate, ExactDecimal.parse('248.10'));
    });

    test(
      'invalid currency without cache reports unsupportedCurrency',
      () async {
        await expectLater(
          repository.getRate('USD', 'XXX'),
          throwsA(
            isA<ExchangeRateException>().having(
              (e) => e.failure,
              'failure',
              ExchangeRateFailure.unsupportedCurrency,
            ),
          ),
        );
      },
    );

    test('forceRefresh fetches even when the cache is fresh', () async {
      local.rates['OMR_INR'] = rateOf('OMR', 'INR', '249.00');
      final lookup = await repository.getRate('OMR', 'INR', forceRefresh: true);
      expect(remote.rateCalls, ['OMR_INR']);
      expect(lookup.origin, RateOrigin.online);
      expect(local.rates['OMR_INR']?.rate, ExactDecimal.parse('249.33'));
    });

    test('a failed forceRefresh keeps the cached rate', () async {
      local.rates['OMR_INR'] = rateOf('OMR', 'INR', '249.00');
      remote.failWith = ExchangeRateFailure.timeout;
      final lookup = await repository.getRate('OMR', 'INR', forceRefresh: true);
      expect(lookup.fallbackReason, ExchangeRateFailure.timeout);
      expect(lookup.rate.rate, ExactDecimal.parse('249.00'));
      expect(local.rates['OMR_INR']?.rate, ExactDecimal.parse('249.00'));
    });

    test('same currency needs no rate and no request', () async {
      final lookup = await repository.getRate('OMR', 'OMR');
      expect(lookup.origin, RateOrigin.identity);
      expect(lookup.rate.rate, ExactDecimal.one);
      expect(remote.rateCalls, isEmpty);
    });

    test('concurrent lookups of one pair share a single request', () async {
      remote.gate = Completer<void>();
      final first = repository.getRate('OMR', 'INR');
      final second = repository.getRate('OMR', 'INR');
      remote.gate!.complete();
      final results = await Future.wait([first, second]);
      expect(remote.rateCalls, ['OMR_INR']);
      expect(results[0], results[1]);
    });

    test('a cache that cannot be read behaves like a miss', () async {
      final broken = CurrencyConverterRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: _ThrowingLocal(),
        clock: () => now,
      );
      final lookup = await broken.getRate('OMR', 'INR');
      expect(lookup.origin, RateOrigin.online);
      expect(lookup.rate.rate, ExactDecimal.parse('249.33'));
    });
  });

  group('reverse pairs', () {
    test(
      'INR → OMR is derived from a fresh OMR → INR with no request',
      () async {
        local.rates['OMR_INR'] = rateOf('OMR', 'INR', '249.33');

        final lookup = await repository.getRate('INR', 'OMR');

        expect(remote.rateCalls, isEmpty);
        expect(lookup.derived, isTrue);
        expect(lookup.origin, RateOrigin.cached);
        expect(lookup.rate.baseCurrency, 'INR');
        expect(lookup.rate.quoteCurrency, 'OMR');
        expect(lookup.rate.rate.toString(), '0.0040107488068');
      },
    );

    test('a weak rate (< 1) is never inverted', () async {
      // 1 / 0.00401 = 249.38, visibly off from the real 249.33.
      local.rates['INR_OMR'] = rateOf('INR', 'OMR', '0.00401');

      final lookup = await repository.getRate('OMR', 'INR');

      expect(remote.rateCalls, ['OMR_INR']);
      expect(lookup.derived, isFalse);
      expect(lookup.rate.rate, ExactDecimal.parse('249.33'));
    });

    test('with both cached on the same day the precise one wins', () async {
      local.rates['OMR_INR'] = rateOf('OMR', 'INR', '249.33');
      local.rates['INR_OMR'] = rateOf('INR', 'OMR', '0.00401');

      final lookup = await repository.getRate('INR', 'OMR');

      expect(lookup.derived, isTrue);
      expect(lookup.rate.rate.toString(), '0.0040107488068');
    });

    test('a newer direct rate beats an older derivable one', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.00',
        rateDate: utcDay(2026, 9, 25),
      );
      local.rates['INR_OMR'] = rateOf('INR', 'OMR', '0.00401');

      final lookup = await repository.getRate('INR', 'OMR');

      expect(lookup.derived, isFalse);
      expect(lookup.rate.rate, ExactDecimal.parse('0.00401'));
    });

    test('a stale derivable pair refreshes the strong direction', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.00',
        rateDate: utcDay(2026, 9, 24),
        fetchedAt: DateTime.utc(2026, 9, 24, 9),
      );

      final lookup = await repository.getRate('INR', 'OMR');

      expect(remote.rateCalls, ['OMR_INR']);
      expect(lookup.origin, RateOrigin.online);
      expect(lookup.derived, isTrue);
      expect(lookup.rate.rate.toString(), '0.0040107488068');
      expect(local.rates['OMR_INR']?.rate, ExactDecimal.parse('249.33'));
    });

    test('offline with only the reverse pair still converts', () async {
      local.rates['OMR_INR'] = rateOf(
        'OMR',
        'INR',
        '248.00',
        rateDate: utcDay(2026, 9, 24),
        fetchedAt: DateTime.utc(2026, 9, 24, 9),
      );
      remote.failWith = ExchangeRateFailure.noConnection;

      final lookup = await repository.getRate('INR', 'OMR');

      expect(lookup.derived, isTrue);
      expect(lookup.fallbackReason, ExchangeRateFailure.noConnection);
    });
  });

  group('getCurrencies', () {
    test('fetches once, then serves the cached list', () async {
      final first = await repository.getCurrencies();
      final second = await repository.getCurrencies();

      expect(remote.currencyCalls, 1);
      expect(first.isPartial, isFalse);
      expect(first.currencies.map((c) => c.code), ['INR', 'OMR', 'THB', 'USD']);
      expect(second.currencies.length, 4);
    });

    test(
      'resolves symbols and keeps the app names for app currencies',
      () async {
        final list = await repository.getCurrencies();
        final byCode = {for (final c in list.currencies) c.code: c};
        expect(byCode['USD']?.name, 'US Dollar');
        expect(byCode['USD']?.symbol, r'$');
        expect(byCode['THB']?.name, 'Thai Baht');
        expect(byCode['THB']?.symbol, '฿');
        expect(byCode['OMR']?.symbol, 'ر.ع.');
      },
    );

    test('refreshes a list older than a week', () async {
      local.currencyList = CachedCurrencyList(
        currencies: const [CurrencyModel(code: 'OMR', name: 'Omani Rial')],
        fetchedAt: now.subtract(const Duration(days: 8)),
      );
      final list = await repository.getCurrencies();
      expect(remote.currencyCalls, 1);
      expect(list.currencies.length, 4);
    });

    test('offline: uses the old cached list', () async {
      local.currencyList = CachedCurrencyList(
        currencies: const [CurrencyModel(code: 'OMR', name: 'Omani Rial')],
        fetchedAt: now.subtract(const Duration(days: 30)),
      );
      remote.failWith = ExchangeRateFailure.noConnection;
      final list = await repository.getCurrencies();
      expect(list.isPartial, isFalse);
      expect(list.currencies.single.code, 'OMR');
    });

    test('offline with no list: falls back to the app currencies', () async {
      remote.failWith = ExchangeRateFailure.noConnection;
      final list = await repository.getCurrencies();
      expect(list.isPartial, isTrue);
      expect(
        list.currencies.map((c) => c.code),
        containsAll(['OMR', 'INR', 'USD']),
      );
    });
  });

  group('preferences', () {
    test('defaults on first launch, then what was saved', () async {
      expect(await repository.loadPreferences(), ConverterPreferences.defaults);
      const saved = ConverterPreferences(
        sourceCode: 'USD',
        targetCode: 'AED',
        amountText: '250',
      );
      await repository.savePreferences(saved);
      expect(await repository.loadPreferences(), saved);
    });
  });
}

class _ThrowingLocal extends FakeCurrencyLocalDataSource {
  @override
  Future<Never> getRate(String base, String quote) =>
      Future.error(StateError('disk I/O error'));
}
