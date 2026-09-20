/// Typed errors returned by category use cases instead of throwing.
enum CategoryErrorType {
  notFound,
  invalidInput,
  duplicateName,
  systemCategory,
  inUse,
  lastActive,
  databaseFailure,
}

class CategoryFailure {
  final CategoryErrorType type;
  final String message;

  const CategoryFailure({required this.type, required this.message});
}

sealed class CategoryResult<T> {
  const CategoryResult();
}

class CategorySuccess<T> extends CategoryResult<T> {
  final T data;
  const CategorySuccess(this.data);
}

class CategoryError<T> extends CategoryResult<T> {
  final CategoryFailure failure;
  const CategoryError(this.failure);
}
