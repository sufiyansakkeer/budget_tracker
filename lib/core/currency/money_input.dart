import 'currency_formatter.dart';
import 'exact_decimal.dart';
import 'money_math.dart';

/// How precisely an amount may be typed, shared by every money field and
/// the validators behind them, so a form never rejects what its field let
/// through.
///
/// An amount may have as many decimals as its currency's minor units, and
/// never fewer than two: OMR 7.125, INR 249.50, and JPY up to two decimals
/// as before. That is exactly [MoneyMath]'s unit, so whatever is entered is
/// summed and compared without being rounded.
abstract final class MoneyInput {
  /// Decimals allowed for an amount in [currency] (OMR 3, INR 2, JPY 2).
  /// An unknown or missing currency gets two.
  static int maxDecimals(String? currency) =>
      MoneyMath.forCurrency(currency ?? '').digits;

  /// The most decimals any supported currency takes, for fields that are
  /// not tied to one currency (such as a filter across budgets).
  static const int anyCurrencyDecimals = 3;

  /// What a field accepts while typing: digits, one point and at most
  /// [decimals] digits after it.
  static RegExp pattern(int decimals) =>
      decimals <= 0 ? RegExp(r'^\d*') : RegExp('^\\d*\\.?\\d{0,$decimals}');

  /// The decimals in [input] beyond what [currency] allows, worded for
  /// [subject] ("Amount cannot have more than 3 decimal places"); null when
  /// the input is within it or is not a decimal number.
  static String? decimalsError(
    String input,
    String? currency, {
    String subject = 'Amount',
  }) {
    final parts = input.trim().split('.');
    final allowed = maxDecimals(currency);
    if (parts.length > 1 && parts[1].length > allowed) {
      return '$subject cannot have more than $allowed decimal places';
    }
    return null;
  }

  /// [amount] as text to edit, with every decimal it has and none it does
  /// not: 250 → "250", 12.5 → "12.5", OMR 7.125 → "7.125". Never rounds a
  /// stored amount to fewer places than it was saved with (up to
  /// [anyCurrencyDecimals]).
  static String forInput(double amount) {
    final fixed = ExactDecimal.fromNum(
      amount,
    ).toStringAsFixed(anyCurrencyDecimals);
    if (!fixed.contains('.')) return fixed;
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// The currency's own minor units, for an amount pad that should only
  /// offer what the currency uses (JPY none, OMR three).
  static int padDecimals(String? currency) =>
      CurrencyFormatter.decimalDigitsFor(currency ?? '');
}
