import '../../domain/entities/exchange_rate.dart';
import '../../domain/entities/exchange_rate_failure.dart';
import '../models/currency_model.dart';

/// Contract for the online exchange-rate provider.
abstract class CurrencyRemoteDataSource {
  /// Latest available reference rate for `base → quote` (ISO codes,
  /// upper case).
  ///
  /// Throws [CurrencyApiException] on any network, HTTP or parsing error.
  Future<ExchangeRate> fetchRate(String base, String quote);

  /// Every currency the provider can quote.
  ///
  /// Throws [CurrencyApiException] on any network, HTTP or parsing error.
  Future<List<CurrencyModel>> fetchCurrencies();
}

/// Typed error from the provider, already classified for the domain.
class CurrencyApiException implements Exception {
  final ExchangeRateFailure failure;
  final int? statusCode;
  final String message;

  const CurrencyApiException(
    this.failure, {
    this.statusCode,
    this.message = '',
  });

  @override
  String toString() =>
      'CurrencyApiException: ${failure.name} (status: $statusCode) $message';
}
