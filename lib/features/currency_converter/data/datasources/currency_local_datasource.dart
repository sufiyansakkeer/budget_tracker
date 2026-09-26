import '../../domain/entities/converter_preferences.dart';
import '../../domain/entities/exchange_rate.dart';
import '../models/currency_model.dart';

/// Local cache for exchange rates and the supported-currency list, plus the
/// converter's remembered pair.
abstract class CurrencyLocalDataSource {
  /// The cached rate stored under `BASE_QUOTE`, or `null`.
  Future<ExchangeRate?> getRate(String base, String quote);

  /// Inserts or replaces the rate for its pair.
  Future<void> saveRate(ExchangeRate rate);

  /// The cached currency list with the time it was fetched, or `null`.
  Future<CachedCurrencyList?> getCurrencies();

  /// Replaces the cached currency list.
  Future<void> saveCurrencies(
    List<CurrencyModel> currencies,
    DateTime fetchedAt,
  );

  /// Stored preferences, or `null` for anything never saved.
  Future<ConverterPreferences?> getPreferences();

  Future<void> savePreferences(ConverterPreferences preferences);
}

class CachedCurrencyList {
  final List<CurrencyModel> currencies;
  final DateTime fetchedAt;

  const CachedCurrencyList({required this.currencies, required this.fetchedAt});
}
