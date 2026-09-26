import '../../../../core/currency/exact_decimal.dart';

/// Why an amount the user typed cannot be converted.
enum AmountInputError {
  empty('Enter an amount'),
  invalid('Enter a valid number'),
  zero('Enter an amount greater than 0'),
  negative("Amount can't be negative"),
  tooLarge('Enter an amount below 1 trillion'),
  tooManyDecimals('Use at most 8 decimal places');

  final String message;

  const AmountInputError(this.message);
}

/// Outcome of [AmountInputValidator.validate]: exactly one of [value] and
/// [error] is set.
class AmountValidation {
  final ExactDecimal? value;
  final AmountInputError? error;

  const AmountValidation.valid(ExactDecimal this.value) : error = null;
  const AmountValidation.invalid(AmountInputError this.error) : value = null;

  bool get isValid => value != null;
}

/// Parses converter input into an exact amount. Never throws.
class AmountInputValidator {
  const AmountInputValidator();

  /// Exclusive upper bound. Large enough for any real conversion, small
  /// enough that results stay readable.
  static final ExactDecimal maxAmount = ExactDecimal.parse('1000000000000');

  static const int maxFractionDigits = 8;

  static final RegExp _number = RegExp(r'^-?(\d+\.?\d*|\.\d+)$');

  AmountValidation validate(String raw) {
    // Spaces are harmless; a comma is the decimal key on many keyboards.
    final text = raw.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    if (text.isEmpty) {
      return const AmountValidation.invalid(AmountInputError.empty);
    }
    if (!_number.hasMatch(text)) {
      return const AmountValidation.invalid(AmountInputError.invalid);
    }
    // "12." while typing means 12.
    final value = ExactDecimal.tryParse(
      text.endsWith('.') ? text.substring(0, text.length - 1) : text,
    );
    if (value == null) {
      return const AmountValidation.invalid(AmountInputError.invalid);
    }
    if (value.isNegative) {
      return const AmountValidation.invalid(AmountInputError.negative);
    }
    if (value.isZero) {
      return const AmountValidation.invalid(AmountInputError.zero);
    }
    if (value >= maxAmount) {
      return const AmountValidation.invalid(AmountInputError.tooLarge);
    }
    if (value.scale > maxFractionDigits) {
      return const AmountValidation.invalid(AmountInputError.tooManyDecimals);
    }
    return AmountValidation.valid(value);
  }
}
