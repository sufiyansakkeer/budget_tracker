import '../../../../core/currency/exact_decimal.dart';
import '../entities/exchange_rate.dart';

/// Converts an amount with an already-loaded rate. Pure and synchronous:
/// changing the amount never needs the network.
class ConvertAmountUseCase {
  const ConvertAmountUseCase();

  /// `amount × rate`, computed exactly and rounded once (half away from
  /// zero) to [targetDecimalDigits], the target currency's minor units.
  ExactDecimal call({
    required ExactDecimal amount,
    required ExchangeRate rate,
    required int targetDecimalDigits,
  }) {
    return (amount * rate.rate).roundToScale(targetDecimalDigits);
  }
}
