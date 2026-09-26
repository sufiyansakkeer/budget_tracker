import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart' show currencyFractionDigits;

import '../../features/settings/domain/entities/currency_entity.dart';
import 'exact_decimal.dart';

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

  // ── Any-currency helpers (currency converter) ────────────────────────────
  //
  // [symbolFor] deliberately falls back to ₹ because app-wide amounts are
  // always in one of [availableCurrencies]. The converter handles every ISO
  // currency the rate provider knows, where that fallback would label a Thai
  // baht amount as rupees, so it resolves symbols with [resolveSymbol].

  /// Display symbol for any ISO 4217 [code].
  ///
  /// Order: the app's own symbol for its settings currencies (so ₹, A$, ر.ع.
  /// look the same everywhere), then the provider's [providerSymbol] unless a
  /// settings currency already owns it (AUD must not borrow USD's bare `$`;
  /// it becomes `AU$`), then the code itself.
  static String resolveSymbol(String code, {String? providerSymbol}) {
    final upper = code.toUpperCase();
    for (final c in availableCurrencies) {
      if (c.code == upper) return c.symbol;
    }
    final candidate = providerSymbol?.trim() ?? '';
    if (candidate.isEmpty) return upper;
    final ownedByAnother = availableCurrencies.any(
      (c) => c.symbol == candidate,
    );
    if (!ownedByAnother) return candidate;
    if (candidate.endsWith(r'$') && upper.length >= 2) {
      return '${upper.substring(0, 2)}\$';
    }
    return upper;
  }

  /// The currency's normal number of decimal places (ISO 4217 minor units as
  /// shipped with `intl`): OMR 3, INR 2, JPY 0.
  static int decimalDigitsFor(String code) =>
      currencyFractionDigits[code.toUpperCase()] ??
      currencyFractionDigits['DEFAULT']!;

  /// Formats an exact [amount] with [symbol] and exactly [decimalDigits]
  /// fraction digits, without ever converting it to a `double`.
  ///
  /// Grouping, symbol position and separators come from the same
  /// `NumberFormat.currency` that [format] uses, so for any value a double
  /// can represent exactly the two methods produce identical text.
  static String formatDecimal(
    ExactDecimal amount, {
    required String symbol,
    required int decimalDigits,
  }) {
    final formatter = NumberFormat.currency(
      symbol: _isolateRtl(symbol),
      decimalDigits: 0,
    );
    final fixed = amount.toStringAsFixed(decimalDigits);
    final negative = fixed.startsWith('-');
    final unsigned = negative ? fixed.substring(1) : fixed;
    final dot = unsigned.indexOf('.');
    final fraction = dot < 0 ? '' : unsigned.substring(dot + 1);
    final integer = BigInt.parse(
      dot < 0 ? unsigned : unsigned.substring(0, dot),
    );

    final grouped = _groupInteger(integer, formatter);
    final decimals = fraction.isEmpty
        ? ''
        : '${formatter.symbols.DECIMAL_SEP}$fraction';
    // Rounding can turn a tiny negative into -0.00; show it unsigned.
    final isNegative = negative && fixed.contains(RegExp('[1-9]'));
    return isNegative
        ? '${formatter.negativePrefix}$grouped$decimals${formatter.negativeSuffix}'
        : '${formatter.positivePrefix}$grouped$decimals${formatter.positiveSuffix}';
  }

  /// Formats an exchange rate such as the `₹249.33` in `1 OMR = ₹249.33`.
  ///
  /// Rates for "weak" directions are tiny (1 INR = 0.0040107 OMR), so the
  /// currency's own decimals would print `0.004`. Up to six significant
  /// digits are kept, never fewer decimals than the currency normally shows.
  static String formatRate(
    ExactDecimal rate, {
    required String symbol,
    required String code,
  }) {
    final significant = rate.toSignificantDigits(6);
    final minimum = decimalDigitsFor(code);
    final digits = significant.scale > minimum ? significant.scale : minimum;
    return formatDecimal(significant, symbol: symbol, decimalDigits: digits);
  }

  static final RegExp _rtlChars = RegExp(
    r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
  );

  /// Arabic-script symbols (ر.ع., د.إ) would otherwise pull the digits that
  /// follow them into their right-to-left run, so `ر.ع.1.000` would render
  /// as `1.000ر.ع.`. A left-to-right mark after the symbol keeps the digits
  /// in reading order. Invisible, and only added to RTL symbols.
  static String _isolateRtl(String symbol) =>
      _rtlChars.hasMatch(symbol) ? '$symbol\u200E' : symbol;

  /// Integer digits with the formatter's grouping. `NumberFormat` formats an
  /// `int` exactly; the manual path only runs for values beyond 64 bits.
  static String _groupInteger(BigInt integer, NumberFormat formatter) {
    if (integer.isValidInt) {
      final text = formatter.format(integer.toInt());
      return text.substring(
        formatter.positivePrefix.length,
        text.length - formatter.positiveSuffix.length,
      );
    }
    final digits = integer.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(formatter.symbols.GROUP_SEP);
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
