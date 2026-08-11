import 'package:intl/intl.dart';

import '../../features/settings/domain/entities/currency_entity.dart';

/// Centralized currency formatting for the whole application.
///
/// All financial values should be formatted through this class so that the
/// correct symbol (e.g. ₹ instead of INR) is shown consistently everywhere.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Resolves the display symbol for a currency [code] (e.g. 'INR' -> '₹').
  /// Defaults to the Indian Rupee symbol when the code is unknown/empty.
  static String symbolFor(String? code) {
    return currencyByCode(code).symbol;
  }

  /// Formats [amount] using the symbol resolved from [code].
  ///
  /// [decimalDigits] controls how many decimal places are shown. When [amount]
  /// is a whole value and [decimalDigits] is not specified, decimals are
  /// omitted to avoid rendering values like `₹1,428.570000`.
  static String format(double amount, {String? code, int? decimalDigits}) {
    final symbol = symbolFor(code);
    final digits = decimalDigits ?? _defaultDigits(amount);
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: digits,
    ).format(amount);
  }

  /// Chooses a sensible default decimal count: 0 for whole amounts, 2 for
  /// fractional amounts where the fraction is meaningful.
  static int _defaultDigits(double amount) {
    final abs = amount.abs();
    if (abs == abs.roundToDouble()) return 0;
    return 2;
  }
}
