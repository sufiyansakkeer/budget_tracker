import '../entities/exchange_rate.dart';

/// Decides whether a cached rate can be used without asking the provider.
///
/// Reference rates are published at most once a day, so the provider's rate
/// date is the primary signal:
///
/// * a rate for today (UTC) is the newest that can exist → fresh;
/// * an older rate is fresh only if it was fetched within
///   [recheckInterval]. That covers weekends, holidays and providers that
///   publish late: the provider just said this was its latest, so asking
///   again on every screen open would only repeat the same answer.
class ExchangeRateFreshnessPolicy {
  final Duration recheckInterval;

  const ExchangeRateFreshnessPolicy({
    this.recheckInterval = const Duration(hours: 6),
  });

  bool isFresh(ExchangeRate rate, DateTime now) {
    final utcNow = now.toUtc();
    final today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    if (!rate.rateDate.isBefore(today)) return true;
    final age = now.difference(rate.fetchedAt);
    // A fetch time in the future means the clock moved; don't trust it.
    return !age.isNegative && age < recheckInterval;
  }
}
