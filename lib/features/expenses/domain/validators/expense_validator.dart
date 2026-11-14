import '../../../../core/currency/money_input.dart';
import '../../../../core/currency/money_math.dart';
import '../entities/expense_entity.dart';
import '../entities/expense_failure.dart';
import '../../../../core/constants/app_copy.dart';

/// Reusable, pure validation logic for expense inputs.
/// Kept outside the UI so it can be unit-tested independently.
class ExpenseValidator {
  const ExpenseValidator._();

  static const int maxNoteLength = 500;
  static const int maxTags = 10;

  /// Validates an amount string in [currency]. Returns null if valid,
  /// otherwise an error message. Decimals follow the currency's minor units,
  /// never fewer than two (OMR 3, INR 2, JPY 2); see [MoneyInput].
  static String? validateAmount(String? input, {String? currency}) {
    if (input == null || input.trim().isEmpty) {
      return ValidationCopy.amountEmpty;
    }

    final value = double.tryParse(input.trim());
    if (value == null) {
      return ValidationCopy.amountInvalid;
    }
    if (!value.isFinite) {
      return ValidationCopy.amountInvalid;
    }
    if (value <= 0) {
      return ValidationCopy.amountNotPositive;
    }
    if (!MoneyMath.isWithinLimit(value)) {
      return ValidationCopy.amountTooLarge;
    }

    return MoneyInput.decimalsError(input, currency);
  }

  /// Validates a double amount value.
  static String? validateAmountValue(double? value) {
    if (value == null) {
      return ValidationCopy.amountEmpty;
    }
    if (!value.isFinite) {
      return ValidationCopy.amountInvalid;
    }
    if (value <= 0) {
      return ValidationCopy.amountNotPositive;
    }
    if (!MoneyMath.isWithinLimit(value)) {
      return ValidationCopy.amountTooLarge;
    }
    return null;
  }

  /// Validates that a category is selected.
  static String? validateCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      return ValidationCopy.categoryMissing;
    }
    return null;
  }

  /// Validates a date is not in the future (unless allowed).
  static String? validateDate(DateTime? date, {DateTime? now}) {
    if (date == null) {
      return ValidationCopy.dateMissing;
    }
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected.isAfter(today)) {
      return ValidationCopy.dateInFuture;
    }
    return null;
  }

  /// Validates a note length.
  static String? validateNote(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    if (note.length > maxNoteLength) {
      return ValidationCopy.noteTooLong(maxNoteLength);
    }
    return null;
  }

  /// Validates a receipt file path exists.
  static String? validateReceiptPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.trim().isEmpty) return 'Invalid receipt path';
    return null;
  }

  /// Every rule an expense must meet to be saved, the same for a new
  /// expense and an edit. Null when it is valid.
  static ExpenseFailure? check(ExpenseEntity expense, {DateTime? now}) {
    final inputError =
        validateAmountValue(expense.amount) ??
        validateCategory(expense.categoryId) ??
        validateDate(expense.date, now: now) ??
        validateNote(expense.note);
    if (inputError != null) {
      return ExpenseFailure(
        type: ExpenseErrorType.invalidInput,
        message: inputError,
      );
    }
    final receiptError = validateReceiptPath(expense.receiptImagePath);
    if (receiptError != null) {
      return ExpenseFailure(
        type: ExpenseErrorType.missingReceipt,
        message: receiptError,
      );
    }
    return null;
  }

  /// Validates the number of tags.
  static String? validateTags(List<String> tags) {
    if (tags.length > maxTags) {
      return 'Cannot add more than $maxTags tags';
    }
    return null;
  }
}
