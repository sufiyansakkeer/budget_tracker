import 'package:equatable/equatable.dart';

/// Bills linked to the budget whose currency differs from the budget's.
/// They cannot be deducted without a conversion, so they are left out and
/// disclosed, and the status can never be "On track" while any exist.
class CurrencyExcludedSummary extends Equatable {
  final int count;

  /// Unconverted total per currency code (e.g. `{'USD': 40}`).
  final Map<String, double> totalsByCurrency;

  const CurrencyExcludedSummary({
    required this.count,
    required this.totalsByCurrency,
  });

  static const none = CurrencyExcludedSummary(count: 0, totalsByCurrency: {});

  bool get isEmpty => count == 0;

  @override
  List<Object?> get props => [count, totalsByCurrency];
}
