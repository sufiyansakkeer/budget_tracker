/// Reusable, pure validation logic for bill inputs.
/// Kept outside the UI so it can be unit-tested independently.
class BillValidator {
  const BillValidator._();

  static const int maxTitleLength = 100;
  static const int maxNoteLength = 500;

  /// Validates a title string. Returns null if valid, otherwise an error message.
  static String? validateTitle(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Bill name cannot be empty';
    }
    if (input.trim().length > maxTitleLength) {
      return 'Bill name cannot exceed $maxTitleLength characters';
    }
    return null;
  }

  /// Validates an amount string. Returns null if valid.
  static String? validateAmount(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Amount cannot be empty';
    }
    final value = double.tryParse(input.trim());
    if (value == null) {
      return 'Please enter a valid number';
    }
    if (!value.isFinite) {
      return 'Amount must be a valid finite number';
    }
    if (value <= 0) {
      return 'Amount must be greater than zero';
    }
    final decimalParts = input.trim().split('.');
    if (decimalParts.length > 1 && decimalParts[1].length > 2) {
      return 'Amount cannot have more than 2 decimal places';
    }
    return null;
  }

  /// Validates a double amount value.
  static String? validateAmountValue(double? value) {
    if (value == null) {
      return 'Amount cannot be empty';
    }
    if (!value.isFinite) {
      return 'Amount must be a valid finite number';
    }
    if (value <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  /// Validates a due date is not in the past.
  static String? validateDueDate(DateTime? date, {DateTime? now}) {
    if (date == null) {
      return 'Please select a due date';
    }
    return null; // Bills CAN have past due dates (overdue).
  }

  /// Validates a note length.
  static String? validateNote(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    if (note.length > maxNoteLength) {
      return 'Note cannot exceed $maxNoteLength characters';
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

  /// Validates reminder offset.
  static String? validateReminderOffset(int offsetDays) {
    if (offsetDays < 0) {
      return 'Reminder offset cannot be negative';
    }
    return null;
  }
}
