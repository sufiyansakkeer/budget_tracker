import '../../../core/errors/user_facing_error.dart';
import '../domain/entities/bill_failure.dart';

/// What a bill failure says on screen.
extension BillFailureCopy on BillFailure {
  /// The failure's own message when it was written for people (validation,
  /// a missing record), otherwise [fallback].
  String shown(String fallback) => userFacingError(
    message,
    forPeople:
        type == BillErrorType.invalidInput || type == BillErrorType.notFound,
    fallback: fallback,
  );
}
