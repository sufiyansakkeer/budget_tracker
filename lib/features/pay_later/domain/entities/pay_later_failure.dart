/// Typed errors returned by Pay Later use cases instead of throwing.
enum PayLaterErrorType {
  notFound,
  invalidInput,

  /// The tab still owes money or holds credit (e.g. archive refused).
  hasBalance,

  /// The tab or value is used and can't change (e.g. currency once used).
  inUse,

  /// A purchase's budget currency differs from the tab's.
  currencyMismatch,
  databaseFailure,
}

/// Failure object for Pay Later operations.
class PayLaterFailure {
  final PayLaterErrorType type;
  final String message;

  const PayLaterFailure({required this.type, required this.message});
}

/// Result of a Pay Later use case.
sealed class PayLaterResult<T> {
  const PayLaterResult();
}

class PayLaterSuccess<T> extends PayLaterResult<T> {
  final T data;

  const PayLaterSuccess(this.data);
}

class PayLaterError<T> extends PayLaterResult<T> {
  final PayLaterFailure failure;

  const PayLaterError(this.failure);
}
