/// Why an exchange rate (or the currency list) could not be fetched.
enum ExchangeRateFailure {
  /// The device could not reach the provider.
  noConnection,

  /// The provider did not answer within the request timeout.
  timeout,

  /// The provider rejected the currency or pair (HTTP 400, 404, 422).
  unsupportedCurrency,

  /// The provider is down or rate limiting (HTTP 429, 5xx).
  serviceUnavailable,

  /// The provider answered with something that is not a valid rate.
  badResponse;

  /// True when the failure is about connectivity, not about the provider.
  bool get isOffline => this == noConnection || this == timeout;
}

/// Thrown when no usable rate exists: the provider failed and nothing is
/// cached for the pair.
class ExchangeRateException implements Exception {
  final ExchangeRateFailure failure;

  const ExchangeRateException(this.failure);

  @override
  String toString() => 'ExchangeRateException: ${failure.name}';
}
