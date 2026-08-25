/// Typed errors returned by budget use cases instead of throwing.
enum BudgetErrorType { notFound, invalidDate, invalidBudget }

/// Failure object for budget operations.
class BudgetFailure {
  final BudgetErrorType type;
  final String message;

  const BudgetFailure({required this.type, required this.message});
}

/// Success wrapper for budget use case results.
sealed class BudgetResult<T> {
  const BudgetResult();
}

class BudgetSuccess<T> extends BudgetResult<T> {
  final T data;

  const BudgetSuccess(this.data);
}

class BudgetError<T> extends BudgetResult<T> {
  final BudgetFailure failure;

  const BudgetError(this.failure);
}
