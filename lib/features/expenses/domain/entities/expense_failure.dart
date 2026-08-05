/// Typed errors returned by expense use cases instead of throwing.
enum ExpenseErrorType {
  notFound,
  invalidInput,
  databaseFailure,
  missingReceipt,
}

/// Failure object for expense operations.
class ExpenseFailure {
  final ExpenseErrorType type;
  final String message;

  const ExpenseFailure({required this.type, required this.message});
}

/// Success wrapper for expense use case results (mirrors budget errors).
sealed class ExpenseResult<T> {
  const ExpenseResult();
}

class ExpenseSuccess<T> extends ExpenseResult<T> {
  final T data;

  const ExpenseSuccess(this.data);
}

class ExpenseError<T> extends ExpenseResult<T> {
  final ExpenseFailure failure;

  const ExpenseError(this.failure);
}
