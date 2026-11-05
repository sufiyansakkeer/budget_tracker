import '../currency/money_math.dart';

/// Words the app uses on more than one screen, so a figure or a state is
/// always called the same thing (UX-092). Sentence case throughout.
abstract final class AppTerms {
  /// The money a budget has left: budget amount minus what was spent.
  static const String remainingBudget = 'Remaining budget';

  /// A budget whose period hasn't begun.
  static const String notStarted = 'Not started';

  /// Making a budget the one Home, quick add and Reports use.
  static const String makeActive = 'Make active';

  /// A domain label shown in sentence case: "This Week" → "This week".
  /// Domain enums keep their own labels; screens show them through this.
  static String sentenceCase(String label) => label.isEmpty
      ? label
      : label[0].toUpperCase() + label.substring(1).toLowerCase();
}

/// Field errors, worded the same way on every form: what to do, as a
/// sentence ending with a full stop.
abstract final class ValidationCopy {
  static const String amountEmpty = 'Enter an amount.';
  static const String amountInvalid = 'Enter a valid number.';
  static const String amountNotPositive = 'Enter an amount greater than zero.';

  /// "Enter an amount less than 1,000,000,000,000."
  static const String amountTooLarge =
      'Enter an amount less than ${MoneyMath.maxAmountLabel}.';

  /// "Use up to 2 decimal places."
  static String tooManyDecimals(int allowed) =>
      'Use up to $allowed decimal ${allowed == 1 ? 'place' : 'places'}.';

  static const String budgetNameEmpty = 'Give your budget a name.';
  static const String billNameEmpty = 'Give the bill a name.';

  /// "Keep the name under 100 characters."
  static String nameTooLong(int max) => 'Keep the name under $max characters.';

  /// "Keep the note under 500 characters."
  static String noteTooLong(int max) => 'Keep the note under $max characters.';

  static const String endBeforeStart =
      'The end date must be after the start date.';
  static const String categoryMissing = 'Choose a category.';
  static const String dateMissing = 'Choose a date.';
  static const String dateInFuture = "The date can't be in the future.";
}
