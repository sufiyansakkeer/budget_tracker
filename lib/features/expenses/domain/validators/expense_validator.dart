/// Reusable, pure validation logic for expense inputs.
/// Kept outside the UI so it can be unit-tested independently.
class ExpenseValidator {
  const ExpenseValidator._();

  static const int maxNoteLength = 500;
  static const int maxTags = 10;

  /// Validates an amount string. Returns null if valid, otherwise an error message.
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

  /// Validates that a category is selected.
  static String? validateCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      return 'Please select a category';
    }
    return null;
  }

  /// Validates a date is not in the future (unless allowed).
  static String? validateDate(DateTime? date, {DateTime? now}) {
    if (date == null) {
      return 'Please select a date';
    }
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected.isAfter(today)) {
      return 'Date cannot be in the future';
    }
    return null;
  }

  /// Validates a note length.
  static String? validateNote(String? note) {
    if (note == null || note.trim().isEmpty) return null;
    if (note.length > maxNoteLength) {
      return 'Note cannot exceed $maxNoteLength characters';
    }
    return null;
  }

  /// Validates a receipt file path exists.
  static String? validateReceiptPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.trim().isEmpty) return 'Invalid receipt path';
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
