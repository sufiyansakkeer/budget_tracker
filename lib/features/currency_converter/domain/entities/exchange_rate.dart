import 'package:equatable/equatable.dart';

import '../../../../core/currency/exact_decimal.dart';

/// A provider exchange rate: `1 [baseCurrency] = [rate] [quoteCurrency]`.
class ExchangeRate extends Equatable {
  final String baseCurrency;
  final String quoteCurrency;

  /// Exact rate, at the provider's full precision (never a rounded display
  /// value).
  final ExactDecimal rate;

  /// The provider's reference day for this rate, as a UTC midnight.
  final DateTime rateDate;

  /// When this device received the rate from the provider.
  final DateTime fetchedAt;

  /// Who published the rate (e.g. `Frankfurter`).
  final String provider;

  const ExchangeRate({
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.rate,
    required this.rateDate,
    required this.fetchedAt,
    required this.provider,
  });

  /// Cache key for a pair: `OMR_INR`.
  static String pairId(String base, String quote) => '${base}_$quote';

  String get id => pairId(baseCurrency, quoteCurrency);

  /// Whether the provider quoted this rate at its full precision.
  ///
  /// Frankfurter returns about five significant digits for rates of 1 or
  /// more (249.33) but only about five *decimal places* below 1 (0.00401).
  /// Only strong rates are inverted: 1 / 249.33 is more precise than the
  /// provider's own 0.00401, while 1 / 0.00401 = 249.38 would be wrong.
  bool get isStrongDirection => rate >= ExactDecimal.one;

  /// The reverse pair, `1 [quoteCurrency] = 1 / [rate] [baseCurrency]`,
  /// kept to 12 significant digits (far beyond the provider's precision, so
  /// the division itself adds no visible error).
  ExchangeRate inverted() => ExchangeRate(
    baseCurrency: quoteCurrency,
    quoteCurrency: baseCurrency,
    rate: ExactDecimal.one.divide(rate, significantDigits: 12),
    rateDate: rateDate,
    fetchedAt: fetchedAt,
    provider: provider,
  );

  @override
  List<Object?> get props => [
    baseCurrency,
    quoteCurrency,
    rate,
    rateDate,
    fetchedAt,
    provider,
  ];
}
