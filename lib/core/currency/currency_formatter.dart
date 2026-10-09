import 'dart:math' as math;

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
  /// [decimalDigits] controls how many decimal places are shown. When it is
  /// not specified, a whole amount shows none (never `₹1,428.570000` or
  /// `₹250.00`) and a fractional one shows as many as amounts in [code] may
  /// be entered with: OMR 7.125 → 3, ₹249.5 → 2.
  static String format(double amount, {String? code, int? decimalDigits}) {
    final symbol = symbolFor(code);
    final digits = decimalDigits ?? _defaultDigits(amount, code);
    return NumberFormat.currency(
      symbol: _beforeNumber(symbol),
      decimalDigits: digits,
    ).format(amount);
  }

  // ── The Omani rial sign ──────────────────────────────────────────────────

  /// U+20C4 OMANI RIAL SIGN, introduced by the Central Bank of Oman in 2025
  /// (Unicode 18.0). No system font draws it yet: the app bundles the glyph
  /// as the `MonivoOmaniRial` fallback font (see
  /// `AppTypography.fontFamilyFallback`), and text that the operating system
  /// draws goes through [forSystemText].
  static const String omaniRialSign = '\u20C4';

  /// What stands in for [omaniRialSign] where the app's fonts can't reach:
  /// the abbreviation used before the sign, with the left-to-right mark that
  /// keeps it in front of the digits.
  static const String omaniRialFallback = 'ر.ع.\u200E';

  /// [text] for surfaces the operating system draws with its own fonts
  /// (notifications), which can't draw [omaniRialSign] yet: the sign and its
  /// space become [omaniRialFallback].
  static String forSystemText(String text) => text
      .replaceAll('$omaniRialSign\u00A0', omaniRialFallback)
      .replaceAll(omaniRialSign, omaniRialFallback);

  /// [text] for a screen reader: speech engines don't know [omaniRialSign]
  /// yet and would skip it, so it is read as the currency code.
  static String forSpeech(String text) => text
      .replaceAll('$omaniRialSign\u00A0', 'OMR ')
      .replaceAll(omaniRialSign, 'OMR ');

  /// [symbol] as written in front of a number. The Omani rial sign takes
  /// the space its guidelines require ("⃄ 10.500"), a no-break space so the
  /// two never wrap apart; Arabic-script symbols get the mark from
  /// [_isolateRtl].
  static String _beforeNumber(String symbol) =>
      symbol == omaniRialSign ? '$symbol\u00A0' : _isolateRtl(symbol);

  /// 0 when [amount] is whole at the precision amounts in [code] are
  /// entered with (the currency's minor units, never fewer than two, as
  /// `MoneyInput.maxDecimals`), otherwise that precision.
  static int _defaultDigits(double amount, String? code) {
    final digits = math.max(decimalDigitsFor(code ?? ''), 2);
    final factor = math.pow(10, digits).toDouble();
    final units = (amount.abs() * factor).round();
    return units % factor.toInt() == 0 ? 0 : digits;
  }

  // ── Any-currency helpers (currency converter) ────────────────────────────
  //
  // [symbolFor] deliberately falls back to ₹ because app-wide amounts are
  // always in one of [availableCurrencies]. The converter handles every ISO
  // currency the rate provider knows, where that fallback would label a Thai
  // baht amount as rupees, so it resolves symbols with [resolveSymbol].

  /// Display symbol for any ISO 4217 [code].
  ///
  /// Order: the app's own symbol for its settings currencies (so ₹, A$, ⃄
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

  /// Decimals to show an exact [amount] with: [code]'s minor units when the
  /// amount has a fraction at that precision, otherwise 0.
  ///
  /// ₹250 → 0 ("₹250"), ₹249.5 → 2 ("₹249.50"), OMR 10.6 → 3 ("10.600"),
  /// JPY 120 → 0. Unlike the default of [format], fractions are never
  /// rounded away and whole amounts never gain ".00".
  static int exactDisplayDigits(double amount, {required String code}) {
    final digits = decimalDigitsFor(code);
    final factor = math.pow(10, digits).toDouble();
    final units = (amount.abs() * factor).round();
    return units % factor.toInt() == 0 ? 0 : digits;
  }

  // ── "Safe" amounts (safe-to-spend) ───────────────────────────────────────
  //
  // `NumberFormat` rounds to nearest, so ₹714.60 shown with 0 decimals reads
  // ₹715 — more than is actually safe. Amounts the user is told they can
  // spend are floored to the digits actually shown instead.

  /// Largest value ≤ [amount] with at most [decimalDigits] fraction digits.
  ///
  /// Values within 1e-6 of a minor unit are snapped to it first, so binary
  /// noise (0.29 × 100 = 28.999999999999996) never loses a whole minor unit.
  /// Intended for non-negative amounts; negatives floor away from zero.
  static double floorToDigits(double amount, int decimalDigits) {
    if (!amount.isFinite) return amount;
    final factor = math.pow(10, decimalDigits).toDouble();
    final scaled = amount * factor;
    final nearest = scaled.roundToDouble();
    final units = (scaled - nearest).abs() <= 1e-6
        ? nearest
        : scaled.floorToDouble();
    return units / factor;
  }

  /// [amount] floored to [code]'s minor units, with the number of decimals to
  /// display it with: the currency's digits when the floored value has a
  /// fraction at that precision, otherwise 0.
  ///
  /// OMR 7.6 → (7.6, 3) renders "7.600", never "8"; ₹1000/3 → (333.33, 2);
  /// ₹1000.004 → (1000, 0); JPY 99.9 → (99, 0).
  static ({double amount, int decimalDigits}) floorForDisplay(
    double amount, {
    required String code,
  }) {
    final digits = decimalDigitsFor(code);
    final floored = floorToDigits(amount, digits);
    final whole = floored == floored.truncateToDouble();
    return (amount: floored, decimalDigits: whole ? 0 : digits);
  }

  /// Formats a "safe" amount (today's safe spending, left today, free to
  /// spend) floored to the digits shown; see [floorForDisplay].
  static String formatFloored(double amount, {required String code}) {
    final display = floorForDisplay(amount, code: code);
    return format(
      display.amount,
      code: code,
      decimalDigits: display.decimalDigits,
    );
  }

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
      symbol: _beforeNumber(symbol),
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

  /// Arabic-script symbols (د.إ) would otherwise pull the digits that follow
  /// them into their right-to-left run, so `د.إ1,000` would render as
  /// `1,000د.إ`, in every sentence that contains it. A left-to-right mark
  /// after the symbol keeps the digits in reading order. Invisible, and only
  /// added to RTL symbols.
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
