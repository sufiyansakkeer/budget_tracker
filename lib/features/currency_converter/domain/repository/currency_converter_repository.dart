import '../../../settings/domain/entities/currency_entity.dart';
import '../entities/converter_preferences.dart';
import '../entities/rate_lookup.dart';

/// Exchange rates, supported currencies and converter preferences.
///
/// The presentation layer must not know that rates come from Frankfurter or
/// that they are cached in Drift.
abstract class CurrencyConverterRepository {
  /// Supported currencies, sorted by code. Served from the local cache while
  /// it is recent; otherwise fetched and cached. Falls back to any cached
  /// list, then to the app's built-in currencies, so it never throws.
  Future<CurrencyList> getCurrencies();

  /// The rate for `base → quote`, cache first.
  ///
  /// A fresh cached rate (direct, or derived from the reverse pair) is
  /// returned without a network call. Otherwise the provider is asked and
  /// the answer cached. If that fails, the newest cached rate is returned
  /// with [RateLookup.fallbackReason] set. [forceRefresh] skips the fresh
  /// cache check (the user tapped "Refresh rate").
  ///
  /// Throws [ExchangeRateException] only when the provider failed and
  /// nothing is cached for the pair.
  Future<RateLookup> getRate(
    String base,
    String quote, {
    bool forceRefresh = false,
  });

  Future<ConverterPreferences> loadPreferences();

  Future<void> savePreferences(ConverterPreferences preferences);
}

/// Result of [CurrencyConverterRepository.getCurrencies].
class CurrencyList {
  final List<CurrencyEntity> currencies;

  /// True when neither the provider nor the cache had a list and only the
  /// app's built-in currencies are available.
  final bool isPartial;

  const CurrencyList({required this.currencies, this.isPartial = false});
}
