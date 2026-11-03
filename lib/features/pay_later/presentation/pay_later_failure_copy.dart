import '../../../core/errors/user_facing_error.dart';
import '../domain/entities/pay_later_failure.dart';

/// What a Pay Later failure says on screen.
extension PayLaterFailureCopy on PayLaterFailure {
  /// The failure's own message when it was written for people (validation,
  /// a missing tab, a refused currency change, a balance), otherwise
  /// [fallback]. Chosen by type, never by message text.
  String shown(String fallback) => userFacingError(
    message,
    forPeople: switch (type) {
      PayLaterErrorType.invalidInput ||
      PayLaterErrorType.notFound ||
      PayLaterErrorType.hasBalance ||
      PayLaterErrorType.inUse ||
      PayLaterErrorType.currencyMismatch => true,
      PayLaterErrorType.databaseFailure => false,
    },
    fallback: fallback,
  );
}
