import 'dart:async';

import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/features/currency_converter/data/datasources/currency_local_datasource.dart';
import 'package:monivo/features/currency_converter/data/datasources/currency_remote_datasource.dart';
import 'package:monivo/features/currency_converter/data/models/currency_model.dart';
import 'package:monivo/features/currency_converter/domain/entities/converter_preferences.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate_failure.dart';

/// 2026-09-26 12:00 UTC — the "now" most converter tests run at.
final DateTime testNow = DateTime.utc(2026, 9, 26, 12);

DateTime utcDay(int y, int m, int d) => DateTime.utc(y, m, d);

ExchangeRate rateOf(
  String base,
  String quote,
  String rate, {
  DateTime? rateDate,
  DateTime? fetchedAt,
}) => ExchangeRate(
  baseCurrency: base,
  quoteCurrency: quote,
  rate: ExactDecimal.parse(rate),
  rateDate: rateDate ?? utcDay(2026, 9, 26),
  fetchedAt: fetchedAt ?? testNow,
  provider: 'Frankfurter',
);

/// Stand-in for the Frankfurter API that records every call.
class FakeCurrencyRemoteDataSource implements CurrencyRemoteDataSource {
  /// Provider rates by `BASE_QUOTE`, as strings.
  final Map<String, String> rates;

  /// Reference day the fake provider reports.
  DateTime rateDate;

  /// When set, every call fails with this.
  ExchangeRateFailure? failWith;

  /// When set, rate calls wait for this before answering.
  Completer<void>? gate;

  List<CurrencyModel> currencies;

  final List<String> rateCalls = [];
  int currencyCalls = 0;

  DateTime Function() clock;

  FakeCurrencyRemoteDataSource({
    Map<String, String>? rates,
    DateTime? rateDate,
    List<CurrencyModel>? currencies,
    DateTime Function()? clock,
  }) : rates = rates ?? {'OMR_INR': '249.33', 'INR_OMR': '0.00401'},
       rateDate = rateDate ?? utcDay(2026, 9, 26),
       currencies =
           currencies ??
           const [
             CurrencyModel(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
             CurrencyModel(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.'),
             CurrencyModel(
               code: 'USD',
               name: 'United States Dollar',
               symbol: r'$',
             ),
             CurrencyModel(code: 'THB', name: 'Thai Baht', symbol: '฿'),
           ],
       clock = clock ?? (() => testNow);

  @override
  Future<ExchangeRate> fetchRate(String base, String quote) async {
    rateCalls.add(ExchangeRate.pairId(base, quote));
    if (gate != null) await gate!.future;
    final failure = failWith;
    if (failure != null) throw CurrencyApiException(failure);
    final rate = rates[ExchangeRate.pairId(base, quote)];
    if (rate == null) {
      throw const CurrencyApiException(
        ExchangeRateFailure.unsupportedCurrency,
        statusCode: 422,
      );
    }
    return rateOf(base, quote, rate, rateDate: rateDate, fetchedAt: clock());
  }

  @override
  Future<List<CurrencyModel>> fetchCurrencies() async {
    currencyCalls++;
    final failure = failWith;
    if (failure != null) throw CurrencyApiException(failure);
    return currencies;
  }
}

/// In-memory cache with the same contract as the Drift-backed one.
class FakeCurrencyLocalDataSource implements CurrencyLocalDataSource {
  final Map<String, ExchangeRate> rates = {};
  CachedCurrencyList? currencyList;
  ConverterPreferences? preferences;
  int saveRateCalls = 0;

  @override
  Future<ExchangeRate?> getRate(String base, String quote) async =>
      rates[ExchangeRate.pairId(base, quote)];

  @override
  Future<void> saveRate(ExchangeRate rate) async {
    saveRateCalls++;
    rates[rate.id] = rate;
  }

  @override
  Future<CachedCurrencyList?> getCurrencies() async => currencyList;

  @override
  Future<void> saveCurrencies(
    List<CurrencyModel> currencies,
    DateTime fetchedAt,
  ) async {
    currencyList = CachedCurrencyList(
      currencies: currencies,
      fetchedAt: fetchedAt,
    );
  }

  @override
  Future<ConverterPreferences?> getPreferences() async => preferences;

  @override
  Future<void> savePreferences(ConverterPreferences preferences) async {
    this.preferences = preferences;
  }
}
