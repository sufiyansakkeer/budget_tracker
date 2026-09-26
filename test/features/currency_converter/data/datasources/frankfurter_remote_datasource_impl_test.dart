import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/features/currency_converter/data/datasources/currency_remote_datasource.dart';
import 'package:monivo/features/currency_converter/data/datasources/frankfurter_remote_datasource_impl.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate_failure.dart';

import '../../helpers/converter_fakes.dart';

void main() {
  late List<Uri> requests;

  FrankfurterRemoteDataSourceImpl sourceWith(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    requests = [];
    return FrankfurterRemoteDataSourceImpl(
      client: MockClient((request) {
        requests.add(request.url);
        return handler(request);
      }),
      clock: () => testNow,
    );
  }

  Matcher failsWith(ExchangeRateFailure failure, {int? status}) => throwsA(
    isA<CurrencyApiException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.statusCode, 'statusCode', status),
  );

  group('fetchRate', () {
    test('calls the HTTPS v2 pair endpoint and parses the rate', () async {
      final source = sourceWith(
        (_) async => http.Response(
          '{"date":"2026-09-26","base":"OMR","quote":"INR","rate":249.33}',
          200,
        ),
      );
      final rate = await source.fetchRate('OMR', 'INR');

      expect(
        requests.single.toString(),
        'https://api.frankfurter.dev/v2/rate/OMR/INR',
      );
      expect(requests.single.scheme, 'https');
      expect(rate.rate, ExactDecimal.parse('249.33'));
      expect(rate.rateDate, DateTime.utc(2026, 9, 26));
      expect(rate.fetchedAt, testNow);
      expect(rate.provider, 'Frankfurter');
    });

    test('rejects invalid codes without a request', () async {
      final source = sourceWith((_) async => http.Response('{}', 200));
      await expectLater(
        source.fetchRate('OM', 'INR'),
        failsWith(ExchangeRateFailure.unsupportedCurrency),
      );
      await expectLater(
        source.fetchRate('OMR', 'inr'),
        failsWith(ExchangeRateFailure.unsupportedCurrency),
      );
      expect(requests, isEmpty);
    });

    for (final (status, failure) in [
      (400, ExchangeRateFailure.unsupportedCurrency),
      (404, ExchangeRateFailure.unsupportedCurrency),
      (422, ExchangeRateFailure.unsupportedCurrency),
      (429, ExchangeRateFailure.serviceUnavailable),
      (500, ExchangeRateFailure.serviceUnavailable),
      (503, ExchangeRateFailure.serviceUnavailable),
      (418, ExchangeRateFailure.badResponse),
    ]) {
      test('maps HTTP $status to ${failure.name}', () async {
        final source = sourceWith(
          (_) async => http.Response(
            '{"status":$status,"message":"invalid currency: XXX"}',
            status,
          ),
        );
        await expectLater(
          source.fetchRate('USD', 'XXX'),
          failsWith(failure, status: status),
        );
      });
    }

    test('maps no connection', () async {
      final source = sourceWith(
        (_) async => throw const SocketException('Failed host lookup'),
      );
      await expectLater(
        source.fetchRate('OMR', 'INR'),
        failsWith(ExchangeRateFailure.noConnection),
      );
    });

    test('maps a client exception to no connection', () async {
      final source = sourceWith(
        (_) async => throw http.ClientException('Connection closed'),
      );
      await expectLater(
        source.fetchRate('OMR', 'INR'),
        failsWith(ExchangeRateFailure.noConnection),
      );
    });

    test('maps a timeout', () async {
      final source = sourceWith((_) async => throw TimeoutException('slow'));
      await expectLater(
        source.fetchRate('OMR', 'INR'),
        failsWith(ExchangeRateFailure.timeout),
      );
    });

    for (final (label, body) in [
      ('empty', ''),
      ('whitespace', '   '),
      ('not JSON', '<html>oops</html>'),
      (
        'JSON without a rate',
        '{"date":"2026-09-26","base":"OMR","quote":"INR"}',
      ),
      (
        'a different pair',
        '{"date":"2026-09-26","base":"OMR","quote":"USD","rate":2.6}',
      ),
      ('a list', '[]'),
    ]) {
      test('maps a $label body to badResponse', () async {
        final source = sourceWith((_) async => http.Response(body, 200));
        await expectLater(
          source.fetchRate('OMR', 'INR'),
          throwsA(
            isA<CurrencyApiException>().having(
              (e) => e.failure,
              'failure',
              ExchangeRateFailure.badResponse,
            ),
          ),
        );
      });
    }
  });

  group('fetchCurrencies', () {
    test('calls the HTTPS currencies endpoint and parses it', () async {
      final source = sourceWith(
        (_) async => http.Response(
          '[{"iso_code":"OMR","name":"Omani Rial","symbol":"ر.ع."},'
          '{"iso_code":"INR","name":"Indian Rupee","symbol":"₹"}]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final list = await source.fetchCurrencies();
      expect(
        requests.single.toString(),
        'https://api.frankfurter.dev/v2/currencies',
      );
      expect(list.map((c) => c.code), ['INR', 'OMR']);
      expect(list.last.symbol, 'ر.ع.');
    });

    test('maps an empty list to badResponse', () async {
      final source = sourceWith((_) async => http.Response('[]', 200));
      await expectLater(
        source.fetchCurrencies(),
        throwsA(
          isA<CurrencyApiException>().having(
            (e) => e.failure,
            'failure',
            ExchangeRateFailure.badResponse,
          ),
        ),
      );
    });
  });
}
