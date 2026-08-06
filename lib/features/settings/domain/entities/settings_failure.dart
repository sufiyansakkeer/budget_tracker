/// Typed errors returned by settings operations instead of throwing.
enum SettingsErrorType {
  loadFailure,
  saveFailure,
  exportFailure,
  importFailure,
  backupFailure,
  restoreFailure,
  biometricUnavailable,
  notificationPermissionDenied,
  invalidData,
  unsupportedSchema,
  notFound,
}

/// Failure object for settings operations.
class SettingsFailure {
  final SettingsErrorType type;
  final String message;

  const SettingsFailure({required this.type, required this.message});
}

/// Success wrapper for settings use case results.
sealed class SettingsResult<T> {
  const SettingsResult();
}

class SettingsSuccess<T> extends SettingsResult<T> {
  final T data;

  const SettingsSuccess(this.data);
}

class SettingsError<T> extends SettingsResult<T> {
  final SettingsFailure failure;

  const SettingsError(this.failure);
}
