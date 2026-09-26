import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/frankfurter_config.dart';
import '../../domain/entities/exchange_rate.dart';
import '../../domain/entities/exchange_rate_failure.dart';
import '../models/currency_model.dart';
import '../models/exchange_rate_model.dart';
import 'currency_remote_datasource.dart';

/// Fetches reference rates and the currency list from the Frankfurter API.
///
/// Every request is HTTPS (`Uri.https` in [FrankfurterConfig]) and carries no
/// credentials: the API has no key.
class FrankfurterRemoteDataSourceImpl implements CurrencyRemoteDataSource {
  final http.Client _client;
  final DateTime Function() _clock;

  FrankfurterRemoteDataSourceImpl({
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static final RegExp _isoCode = RegExp(r'^[A-Z]{3}$');

  @override
  Future<ExchangeRate> fetchRate(String base, String quote) async {
    // A malformed code would only earn a 404/422; don't spend a request.
    if (!_isoCode.hasMatch(base) || !_isoCode.hasMatch(quote)) {
      throw CurrencyApiException(
        ExchangeRateFailure.unsupportedCurrency,
        message: 'Invalid currency code: $base/$quote',
      );
    }
    final json = await _getJson(FrankfurterConfig.rateUri(base, quote));
    try {
      return ExchangeRateModel.fromJson(
        json,
        expectedBase: base,
        expectedQuote: quote,
        fetchedAt: _clock(),
        provider: FrankfurterConfig.providerName,
      );
    } on FormatException catch (e) {
      throw CurrencyApiException(
        ExchangeRateFailure.badResponse,
        message: e.message,
      );
    }
  }

  @override
  Future<List<CurrencyModel>> fetchCurrencies() async {
    final json = await _getJson(FrankfurterConfig.currenciesUri());
    try {
      return CurrencyModel.listFromJson(json);
    } on FormatException catch (e) {
      throw CurrencyApiException(
        ExchangeRateFailure.badResponse,
        message: e.message,
      );
    }
  }

  Future<Object?> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(FrankfurterConfig.requestTimeout);
    } on TimeoutException {
      throw const CurrencyApiException(ExchangeRateFailure.timeout);
    } catch (e) {
      // SocketException / ClientException / HandshakeException: the device
      // could not reach the server.
      throw CurrencyApiException(
        ExchangeRateFailure.noConnection,
        message: e.toString(),
      );
    }

    final status = response.statusCode;
    if (status != 200) {
      throw CurrencyApiException(
        _failureForStatus(status),
        statusCode: status,
        message: _errorMessage(response.body),
      );
    }
    if (response.body.trim().isEmpty) {
      throw const CurrencyApiException(
        ExchangeRateFailure.badResponse,
        statusCode: 200,
        message: 'Empty response',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const CurrencyApiException(
        ExchangeRateFailure.badResponse,
        statusCode: 200,
        message: 'Response is not JSON',
      );
    }
  }

  static ExchangeRateFailure _failureForStatus(int status) {
    switch (status) {
      case 400:
      case 404:
      case 422:
        return ExchangeRateFailure.unsupportedCurrency;
      case 429:
        return ExchangeRateFailure.serviceUnavailable;
      default:
        return status >= 500
            ? ExchangeRateFailure.serviceUnavailable
            : ExchangeRateFailure.badResponse;
    }
  }

  /// Frankfurter errors look like `{"status":422,"message":"invalid currency: XXX"}`.
  static String _errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['message'] != null) {
        return json['message'].toString();
      }
    } catch (_) {
      // Not JSON; fall through.
    }
    return '';
  }
}
