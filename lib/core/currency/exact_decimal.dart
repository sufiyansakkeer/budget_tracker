import 'package:equatable/equatable.dart';

/// An exact base-10 number: `unscaled / 10^scale`.
///
/// Amounts elsewhere in the app are `double`s, which cannot represent most
/// decimal fractions (0.1 + 0.2 != 0.3). Currency conversion multiplies a
/// user amount by an exchange rate that can carry more decimals than either
/// currency, so it runs on this type instead: multiplication is exact and
/// the only rounding happens once, when [roundToScale] brings the result to
/// the target currency's minor units.
///
/// Values are normalised (trailing fractional zeros removed), so equality is
/// numeric: `ExactDecimal.parse('1.50') == ExactDecimal.parse('1.5')`.
class ExactDecimal extends Equatable implements Comparable<ExactDecimal> {
  final BigInt _unscaled;

  /// Number of digits after the decimal point. Never negative.
  final int scale;

  ExactDecimal._(BigInt unscaled, int scale)
    : _unscaled = _normalisedUnscaled(unscaled, scale),
      scale = _normalisedScale(unscaled, scale);

  static final ExactDecimal zero = ExactDecimal._(BigInt.zero, 0);
  static final ExactDecimal one = ExactDecimal._(BigInt.one, 0);

  static final RegExp _pattern = RegExp(
    r'^([+-])?(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );

  /// Parses a plain or exponent decimal string (`'249.33'`, `'-0.5'`,
  /// `'1e-7'`). Throws [FormatException] for anything else.
  factory ExactDecimal.parse(String source) {
    final value = tryParse(source);
    if (value == null) {
      throw FormatException('Not a decimal number', source);
    }
    return value;
  }

  /// Like [ExactDecimal.parse] but returns `null` for invalid input.
  static ExactDecimal? tryParse(String source) {
    final match = _pattern.firstMatch(source.trim());
    if (match == null) return null;
    final whole = match.group(2) ?? '';
    final fraction = match.group(3) ?? '';
    if (whole.isEmpty && fraction.isEmpty) return null;
    final exponent = int.tryParse(match.group(4) ?? '0');
    if (exponent == null || exponent.abs() > 1000) return null;

    var unscaled = BigInt.parse('${whole.isEmpty ? '0' : whole}$fraction');
    if (match.group(1) == '-') unscaled = -unscaled;
    var scale = fraction.length - exponent;
    if (scale < 0) {
      unscaled *= BigInt.from(10).pow(-scale);
      scale = 0;
    }
    return ExactDecimal._(unscaled, scale);
  }

  /// Converts a JSON number without inheriting binary noise: Dart prints a
  /// double as the shortest decimal that round-trips, which for a value
  /// decoded from `"rate": 249.33` is exactly `249.33`.
  factory ExactDecimal.fromNum(num value) {
    if (value is double && !value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    return ExactDecimal.parse(value.toString());
  }

  bool get isZero => _unscaled == BigInt.zero;
  bool get isNegative => _unscaled.isNegative;

  ExactDecimal operator *(ExactDecimal other) =>
      ExactDecimal._(_unscaled * other._unscaled, scale + other.scale);

  ExactDecimal operator -() => ExactDecimal._(-_unscaled, scale);

  bool operator <(ExactDecimal other) => compareTo(other) < 0;
  bool operator <=(ExactDecimal other) => compareTo(other) <= 0;
  bool operator >(ExactDecimal other) => compareTo(other) > 0;
  bool operator >=(ExactDecimal other) => compareTo(other) >= 0;

  /// `this / divisor`, rounded half away from zero to [significantDigits].
  ///
  /// Division is the one operation that can produce an infinite expansion
  /// (1 / 3), so the caller chooses how much precision to keep.
  ExactDecimal divide(ExactDecimal divisor, {int significantDigits = 20}) {
    if (divisor.isZero) {
      throw ArgumentError.value(divisor, 'divisor', 'must not be zero');
    }
    if (isZero) return zero;
    // this / divisor == (a * 10^sb) / (b * 10^sa)
    final numerator = _unscaled.abs() * _pow10(divisor.scale);
    final denominator = divisor._unscaled.abs() * _pow10(scale);
    // Pick a result scale that leaves at least [significantDigits] digits.
    final magnitude =
        numerator.toString().length - denominator.toString().length;
    final resultScale = significantDigits - magnitude;
    final shiftedNumerator = resultScale >= 0
        ? numerator * _pow10(resultScale)
        : numerator;
    final shiftedDenominator = resultScale >= 0
        ? denominator
        : denominator * _pow10(-resultScale);
    var quotient = _divideRoundHalfUp(shiftedNumerator, shiftedDenominator);
    if (isNegative != divisor.isNegative) quotient = -quotient;
    if (resultScale >= 0) return ExactDecimal._(quotient, resultScale);
    return ExactDecimal._(quotient * _pow10(-resultScale), 0);
  }

  /// Rounds half away from zero to [digits] decimal places (the rounding
  /// people expect on a receipt: 2.345 → 2.35, -2.345 → -2.35).
  ExactDecimal roundToScale(int digits) {
    RangeError.checkNotNegative(digits, 'digits');
    if (digits >= scale) return this;
    final divisor = _pow10(scale - digits);
    final rounded = _divideRoundHalfUp(_unscaled.abs(), divisor);
    return ExactDecimal._(isNegative ? -rounded : rounded, digits);
  }

  /// Rounds the *fractional* part so that at most [digits] significant digits
  /// remain. Integer digits are never rounded away (58108 stays 58108).
  ExactDecimal toSignificantDigits(int digits) {
    if (isZero) return this;
    final digitCount = _unscaled.abs().toString().length;
    // Digits to the left of the decimal point (negative for 0.00x values).
    final integerDigits = digitCount - scale;
    final targetScale = digits - integerDigits;
    if (targetScale >= scale) return this;
    return roundToScale(targetScale < 0 ? 0 : targetScale);
  }

  /// Plain decimal text with exactly [digits] fraction digits, rounding half
  /// away from zero. Never uses exponent notation.
  String toStringAsFixed(int digits) {
    final rounded = roundToScale(digits);
    final padded = rounded._unscaled.abs() * _pow10(digits - rounded.scale);
    var text = padded.toString();
    if (digits > 0) {
      text = text.padLeft(digits + 1, '0');
      final split = text.length - digits;
      text = '${text.substring(0, split)}.${text.substring(split)}';
    }
    return rounded.isNegative ? '-$text' : text;
  }

  /// The integer part of the absolute value (`-12.7` → `12`).
  BigInt get absIntegerPart => _unscaled.abs() ~/ _pow10(scale);

  /// Nearest double. Only for places that genuinely need a `num` (charts,
  /// legacy APIs); never feed the result back into money arithmetic.
  double toDouble() => double.parse(toString());

  /// Canonical plain text (`'249.33'`, `'0.00401'`, `'58108'`); what the
  /// cache stores, and what [ExactDecimal.parse] reads back unchanged.
  @override
  String toString() => toStringAsFixed(scale);

  @override
  int compareTo(ExactDecimal other) {
    final common = scale > other.scale ? scale : other.scale;
    final a = _unscaled * _pow10(common - scale);
    final b = other._unscaled * _pow10(common - other.scale);
    return a.compareTo(b);
  }

  @override
  List<Object?> get props => [_unscaled, scale];

  static BigInt _pow10(int exponent) => BigInt.from(10).pow(exponent);

  /// Rounds `n / d` half away from zero for non-negative [n] and positive [d].
  static BigInt _divideRoundHalfUp(BigInt n, BigInt d) =>
      (n * BigInt.two + d) ~/ (d * BigInt.two);

  static BigInt _normalisedUnscaled(BigInt unscaled, int scale) {
    var value = unscaled;
    var s = scale;
    final ten = BigInt.from(10);
    while (s > 0 && value != BigInt.zero && value % ten == BigInt.zero) {
      value ~/= ten;
      s--;
    }
    return value;
  }

  static int _normalisedScale(BigInt unscaled, int scale) {
    if (unscaled == BigInt.zero) return 0;
    var value = unscaled;
    var s = scale;
    final ten = BigInt.from(10);
    while (s > 0 && value % ten == BigInt.zero) {
      value ~/= ten;
      s--;
    }
    return s;
  }
}
