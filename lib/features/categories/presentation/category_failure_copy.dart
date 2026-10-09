import '../../../core/errors/user_facing_error.dart';
import '../domain/entities/category_failure.dart';

/// What a category failure says on screen.
extension CategoryFailureCopy on CategoryFailure {
  /// The failure's own message unless it is an unexpected database error,
  /// which shows [fallback] instead.
  String shown(String fallback) => userFacingError(
    message,
    forPeople: type != CategoryErrorType.databaseFailure,
    fallback: fallback,
  );
}
