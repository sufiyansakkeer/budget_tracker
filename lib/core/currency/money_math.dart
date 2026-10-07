import 'dart:math' as math;

import 'currency_formatter.dart';
import 'exact_decimal.dart';

/// Integer money arithmetic for one currency.
///
/// Amounts are stored as `double`s, so `0.1 + 0.2` is `0.30000000000000004`.
/// Money code that adds and subtracts several amounts converts each one to
/// integer units ONCE with [toUnits], does all sums and differences on the
/// ints, and converts the result back with [toAmount].
///
/// The unit is 10^-[digits] where [digits] is the currency's minor-unit count
/// but never fewer than 2: the expense and bill forms accept two decimals for
/// every currency, so a JPY expense of 100.5 must not be rounded away before
/// it is summed.
///
/// Range: the forms and use cases accept amounts below [maxAmount], at most
/// 10^15 units (the app's currencies have at most 3 decimals). [toUnits] refuses anything above [maxUnits]
/// (2^53) with an [ArgumentError] instead of overflowing, so a sum of a
/// handful of unit values always fits in a 64-bit int. Products of unit
/// values with day counts can still exceed it; callers do those in
/// [BigInt].
class MoneyMath {
  /// Amounts must be below this (one trillion in any currency): the limit
  /// every amount field and use case enforces.
  static const double maxAmount = 1e12;

  /// [maxAmount] as shown in validation messages.
  static const String maxAmountLabel = '1,000,000,000,000';

  /// Largest magnitude [toUnits] returns (2^53): every unit count up to it
  /// is exact as a double, and 1,024 of them still sum within 64 bits.
  static const int maxUnits = 9007199254740992;

  /// Whether [amount] is a finite value below [maxAmount] in magnitude.
  static bool isWithinLimit(double amount) =>
      amount.isFinite && amount.abs() < maxAmount;

  /// Decimal places one unit represents (OMR 3, INR 2, JPY 2).
  final int digits;

  /// Units per whole currency unit (10^[digits]).
  final int scale;

  MoneyMath._(this.digits) : scale = math.pow(10, digits).toInt();

  /// Arithmetic for [currencyCode], scaled to
  /// `max(CurrencyFormatter.decimalDigitsFor(currencyCode), 2)` digits.
  factory MoneyMath.forCurrency(String currencyCode) => MoneyMath._(
    math.max(CurrencyFormatter.decimalDigitsFor(currencyCode), 2),
  );

  /// [amount] in integer units, rounded half away from zero on its decimal
  /// value (0.145 → 15 at 2 digits, although 0.145 × 100 is
  /// 14.499999999999998 in binary).
  ///
  /// Throws [ArgumentError] for NaN, infinity, or a result above [maxUnits]
  /// in magnitude (amounts far beyond [maxAmount], e.g. corrupt data).
  int toUnits(double amount) {
    if (!amount.isFinite) {
      throw ArgumentError.value(amount, 'amount', 'must be finite');
    }
    final fixed = ExactDecimal.fromNum(amount).toStringAsFixed(digits);
    final units = int.tryParse(fixed.replaceFirst('.', ''));
    if (units == null || units.abs() > maxUnits) {
      throw ArgumentError.value(amount, 'amount', 'is too large');
    }
    return units;
  }

  /// The sum of [amounts] in units, each converted with [toUnits]. Throws
  /// [ArgumentError] when the running total leaves the ±[maxUnits] range.
  int sumUnits(Iterable<double> amounts) {
    var sum = 0;
    for (final amount in amounts) {
      sum += toUnits(amount);
      if (sum.abs() > maxUnits) {
        throw ArgumentError.value(sum, 'sum', 'is too large');
      }
    }
    return sum;
  }

  /// [units] (whole or fractional, e.g. a quotient) back in currency units.
  double toAmount(num units) => units / scale;
}
