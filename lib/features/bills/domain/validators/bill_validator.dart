import '../../../../core/currency/money_input.dart';
import '../../../../core/currency/money_math.dart';
import '../entities/bill_entity.dart';
import '../../../../core/constants/app_copy.dart';

/// Reusable, pure validation logic for bill inputs.
/// Kept outside the UI so it can be unit-tested independently.
class BillValidator {
  const BillValidator._();

  static const int maxTitleLength = 100;
  static const int maxNoteLength = 500;

  /// Validates a title string. Returns null if valid, otherwise an error message.
  static String? validateTitle(String? input) {
    if (input == null || input.trim().isEmpty) {
      return ValidationCopy.billNameEmpty;
    }
    if (input.trim().length > maxTitleLength) {
      return ValidationCopy.nameTooLong(maxTitleLength);
    }
    return null;
  }

  /// Validates an amount string in [currency]. Returns null if valid.
  /// Decimals follow the currency's minor units, never fewer than two.
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

  /// Validates that a due date is set. A past date is allowed: the bill is
  /// then overdue.
  static String? validateDueDate(DateTime? date) {
    if (date == null) {
      return 'Choose a due date.';
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

  /// Validates recurrence settings.
  static String? validateRecurrence({
    required bool isRecurring,
    required int recurrenceInterval,
  }) {
    if (!isRecurring) return null;
    if (recurrenceInterval < 1) {
      return 'Recurrence interval must be at least 1';
    }
    return null;
  }

  /// Every rule a bill must meet to be saved, the same for a new bill and an
  /// edit. Returns the first problem, or null when the bill is valid.
  static String? check(BillEntity bill) =>
      validateTitle(bill.title) ??
      validateAmountValue(bill.amount) ??
      validateDueDate(bill.dueDate) ??
      validateNote(bill.note) ??
      validateRecurrence(
        isRecurring: bill.isRecurring,
        recurrenceInterval: bill.recurrenceInterval,
      );

  /// Validates reminder offset.
  static String? validateReminderOffset(int offsetDays) {
    if (offsetDays < 0) {
      return 'Reminder offset cannot be negative';
    }
    return null;
  }
}
