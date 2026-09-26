import 'package:intl/intl.dart';

import '../../domain/entities/exchange_rate_failure.dart';
import '../../domain/entities/rate_lookup.dart';

/// User-facing wording for the converter, kept in one place so the screen
/// always explains where a rate came from in the same terms.
abstract final class ConverterCopy {
  /// Shown when there is no rate at all for the pair.
  static String failureMessage(
    ExchangeRateFailure failure, {
    required String base,
    required String quote,
  }) {
    switch (failure) {
      case ExchangeRateFailure.noConnection:
        return 'An internet connection is required to get the exchange rate '
            'for this currency pair.';
      case ExchangeRateFailure.timeout:
        return 'The exchange-rate service took too long to respond. Check '
            'your connection and try again.';
      case ExchangeRateFailure.unsupportedCurrency:
        return "The rate provider doesn't publish a rate for $base → $quote. "
            'Try a different currency.';
      case ExchangeRateFailure.serviceUnavailable:
        return 'The exchange-rate service is temporarily unavailable. Please '
            'try again in a few minutes.';
      case ExchangeRateFailure.badResponse:
        return 'The exchange-rate service sent an unexpected response. Please '
            'try again later.';
    }
  }

  static String failureTitle(ExchangeRateFailure failure) =>
      failure.isOffline ? "You're offline" : "Couldn't get the rate";

  /// Short label for the source chip.
  static String sourceLabel(RateLookup lookup) {
    if (lookup.fallbackReason != null) {
      return lookup.fallbackReason!.isOffline ? 'Offline' : "Couldn't update";
    }
    switch (lookup.origin) {
      case RateOrigin.online:
        return 'Online rate';
      case RateOrigin.cached:
        return 'Saved rate';
      case RateOrigin.identity:
        return 'Same currency';
    }
  }

  /// The sentence under the rate that says how it was obtained.
  static String sourceDetail(RateLookup lookup, DateTime now) {
    final rateDay = rateDateLabel(lookup.rate.rateDate, now);
    if (lookup.fallbackReason != null) {
      return lookup.fallbackReason!.isOffline
          ? 'Offline — using saved rate from $rateDay'
          : "Couldn't update. Using saved rate from $rateDay";
    }
    switch (lookup.origin) {
      case RateOrigin.online:
        return 'Updated ${_relativeDay(lookup.rate.rateDate, now) ?? rateDay}';
      case RateOrigin.cached:
        return 'Saved rate from $rateDay';
      case RateOrigin.identity:
        return 'No conversion needed';
    }
  }

  /// "Fetched today, 10:42 AM" / "Saved 25 Sep 2026, 6:03 PM".
  static String fetchedLabel(RateLookup lookup, DateTime now) {
    final local = lookup.rate.fetchedAt.toLocal();
    final day = _relativeDay(local, now) ?? DateFormat.yMMMd().format(local);
    final time = DateFormat.jm().format(local);
    final verb = lookup.origin == RateOrigin.online ? 'Fetched' : 'Saved';
    return '$verb $day, $time';
  }

  /// The provider's reference day: "today", "yesterday" or "Sep 25, 2026".
  static String rateDateLabel(DateTime rateDate, DateTime now) =>
      _relativeDay(rateDate, now) ??
      DateFormat.yMMMd().format(
        DateTime(rateDate.year, rateDate.month, rateDate.day),
      );

  static String derivedNote(RateLookup lookup) =>
      'Calculated from the ${lookup.rate.quoteCurrency} → '
      '${lookup.rate.baseCurrency} rate';

  static const String disclaimer =
      'Daily reference rates from central banks and official sources via '
      'Frankfurter. Not a live market or bank rate.';

  static const String refreshFailed = "Couldn't update. Using saved rate.";
  static const String refreshSucceeded = 'Rate updated';

  /// "today" / "yesterday" relative to the user's calendar day, reading
  /// [day]'s own calendar fields (a UTC reference day keeps its date).
  static String? _relativeDay(DateTime day, DateTime now) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final diff = today
        .difference(DateTime(day.year, day.month, day.day))
        .inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return null;
  }
}
