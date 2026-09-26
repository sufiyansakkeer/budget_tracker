import '../entities/rate_lookup.dart';
import '../repository/currency_converter_repository.dart';

/// Looks up the rate for a currency pair, cache first.
class GetExchangeRateUseCase {
  final CurrencyConverterRepository repository;

  const GetExchangeRateUseCase({required this.repository});

  /// See [CurrencyConverterRepository.getRate].
  Future<RateLookup> call(
    String base,
    String quote, {
    bool forceRefresh = false,
  }) => repository.getRate(base, quote, forceRefresh: forceRefresh);
}
