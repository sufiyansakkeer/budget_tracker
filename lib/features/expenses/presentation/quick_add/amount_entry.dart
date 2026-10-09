import 'package:intl/intl.dart';

import '../../../../core/currency/money_input.dart';
import '../../domain/validators/expense_validator.dart';

/// What has been typed on the amount pad, kept as text so a trailing "."
/// or "0" stays exactly as entered.
///
/// The pad never produces an amount [ExpenseValidator] would reject: the
/// fraction stops at the currency's minor units (OMR three, INR two, JPY
/// none, so JPY gets no decimal key), which the validator always accepts,
/// and the whole part stops at the largest amount the app accepts.
class AmountEntry {
  /// Digits typed, with at most one "." (e.g. "1250.5").
  final String text;

  /// How many digits may follow the decimal point.
  final int maxFractionDigits;

  /// 999,999,999,999 is the largest whole amount below the app's limit.
  static const int maxWholeDigits = 12;

  const AmountEntry._(this.text, this.maxFractionDigits);

  /// An empty entry for [currency].
  factory AmountEntry.empty(String? currency) =>
      AmountEntry._('', MoneyInput.padDecimals(currency));

  /// An entry pre-filled with [amount], trimmed to what the pad allows.
  factory AmountEntry.of(double amount, String? currency) {
    final empty = AmountEntry.empty(currency);
    if (amount <= 0 || !amount.isFinite) return empty;
    final fixed = amount.toStringAsFixed(empty.maxFractionDigits);
    final trimmed = fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
    return AmountEntry._(trimmed, empty.maxFractionDigits);
  }

  /// The same digits under [currency]'s rules, e.g. once the budget (and so
  /// the currency) is known. Extra decimals are dropped, never rounded.
  AmountEntry forCurrency(String? currency) {
    final max = AmountEntry.empty(currency).maxFractionDigits;
    if (max == maxFractionDigits) return this;
    final fraction = _fraction;
    if (fraction == null) return AmountEntry._(text, max);
    if (max == 0) return AmountEntry._(_whole, max);
    final kept = fraction.length > max ? fraction.substring(0, max) : fraction;
    return AmountEntry._('$_whole.$kept', max);
  }

  bool get allowsDecimal => maxFractionDigits > 0;
  bool get isEmpty => text.isEmpty;

  String get _whole => text.split('.').first;
  String? get _fraction => text.contains('.') ? text.split('.')[1] : null;

  /// The amount entered, or 0 when nothing (or only "0.") has been typed.
  double get value => double.tryParse(text) ?? 0;

  /// The entry as a string the validator accepts ("12.5", never "12.").
  String get normalized =>
      text.endsWith('.') ? text.substring(0, text.length - 1) : text;

  AmountEntry digit(int d) {
    assert(d >= 0 && d <= 9);
    final fraction = _fraction;
    if (fraction != null) {
      if (fraction.length >= maxFractionDigits) return this;
      return AmountEntry._('$text$d', maxFractionDigits);
    }
    // A leading zero is replaced, so "0" then "7" reads "7", not "07".
    if (text == '0') return AmountEntry._('$d', maxFractionDigits);
    if (_whole.length >= maxWholeDigits) return this;
    return AmountEntry._('$text$d', maxFractionDigits);
  }

  AmountEntry decimal() {
    if (!allowsDecimal || text.contains('.')) return this;
    return AmountEntry._(text.isEmpty ? '0.' : '$text.', maxFractionDigits);
  }

  AmountEntry backspace() => text.isEmpty
      ? this
      : AmountEntry._(text.substring(0, text.length - 1), maxFractionDigits);

  AmountEntry clear() => AmountEntry._('', maxFractionDigits);

  /// The digits as shown while typing: grouped whole part, then the
  /// fraction exactly as typed ("1,250.5", "0.", "0" when empty).
  String get display {
    final whole = _whole.isEmpty ? 0 : int.parse(_whole);
    final grouped = NumberFormat.decimalPattern().format(whole);
    final fraction = _fraction;
    return fraction == null ? grouped : '$grouped.$fraction';
  }

  @override
  bool operator ==(Object other) =>
      other is AmountEntry &&
      other.text == text &&
      other.maxFractionDigits == maxFractionDigits;

  @override
  int get hashCode => Object.hash(text, maxFractionDigits);
}
