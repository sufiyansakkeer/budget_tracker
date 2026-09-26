/// Configuration for the Frankfurter exchange-rate API used by the currency
/// converter.
///
/// Frankfurter publishes daily *reference* rates from central banks and
/// other official sources. It needs no API key and is only reached over
/// HTTPS. See https://frankfurter.dev/.
class FrankfurterConfig {
  FrankfurterConfig._();

  /// Host of the versioned API. Requests are built with `Uri.https`, so a
  /// plain-HTTP URL can never be produced.
  static const String host = 'api.frankfurter.dev';

  /// Path prefix for API v2.
  static const String basePath = '/v2';

  /// Name recorded with every cached rate.
  static const String providerName = 'Frankfurter';

  static const Duration requestTimeout = Duration(seconds: 10);

  /// `GET /v2/rate/{base}/{quote}` → `{date, base, quote, rate}`.
  static Uri rateUri(String base, String quote) =>
      Uri.https(host, '$basePath/rate/$base/$quote');

  /// `GET /v2/currencies` → `[{iso_code, name, symbol, end_date, ...}]`.
  static Uri currenciesUri() => Uri.https(host, '$basePath/currencies');
}
