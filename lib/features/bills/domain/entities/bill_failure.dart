/// Typed errors returned by bill use cases instead of throwing.
enum BillErrorType {
  notFound,
  invalidInput,
  databaseFailure,
  notificationFailure,
}

/// Failure object for bill operations.
class BillFailure {
  final BillErrorType type;
  final String message;

  const BillFailure({required this.type, required this.message});
}

/// Success wrapper for bill use case results.
sealed class BillResult<T> {
  const BillResult();
}

class BillSuccess<T> extends BillResult<T> {
  final T data;

  const BillSuccess(this.data);
}

class BillError<T> extends BillResult<T> {
  final BillFailure failure;

  const BillError(this.failure);
}
