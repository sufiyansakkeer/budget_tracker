import '../../../core/errors/user_facing_error.dart';
import '../domain/entities/expense_failure.dart';

/// What an expense failure says on screen.
extension ExpenseFailureCopy on ExpenseFailure {
  /// The failure's own message when it was written for people (validation,
  /// a missing record), otherwise [fallback].
  String shown(String fallback) => userFacingError(
    message,
    forPeople:
        type == ExpenseErrorType.invalidInput ||
        type == ExpenseErrorType.notFound ||
        type == ExpenseErrorType.missingReceipt,
    fallback: fallback,
  );
}
