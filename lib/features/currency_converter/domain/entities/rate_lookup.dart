import 'package:equatable/equatable.dart';

import 'exchange_rate.dart';
import 'exchange_rate_failure.dart';

/// Where the rate in a [RateLookup] came from.
enum RateOrigin {
  /// Fetched from the provider during this lookup.
  online,

  /// Read from the local cache.
  cached,

  /// Base and quote are the same currency; the rate is exactly 1.
  identity,
}

/// The answer to "what is the rate for this pair?", plus how it was obtained
/// so the UI can always say whether the user is looking at a fresh, saved or
/// derived rate.
class RateLookup extends Equatable {
  /// Always expressed in the requested direction, even when [derived].
  final ExchangeRate rate;

  final RateOrigin origin;

  /// Computed as `1 / rate` from the cached reverse pair instead of being
  /// fetched for this direction.
  final bool derived;

  /// Set when a fetch was attempted and failed, so [rate] is a cached
  /// fallback that may be out of date.
  final ExchangeRateFailure? fallbackReason;

  const RateLookup({
    required this.rate,
    required this.origin,
    this.derived = false,
    this.fallbackReason,
  });

  bool get isFallback => fallbackReason != null;

  @override
  List<Object?> get props => [rate, origin, derived, fallbackReason];
}
