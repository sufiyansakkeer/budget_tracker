/// The outcome of one attempt to unlock the app.
///
/// Only [success] opens the app. Every other outcome keeps the lock gate
/// up with a message saying what to do: the lock never opens just because
/// the check could not run.
enum LockAuthResult {
  /// The user confirmed it is them.
  success,

  /// The prompt was cancelled, or the biometric did not match.
  failed,

  /// The device has no screen lock and no enrolled biometrics, so there is
  /// nothing to confirm against. Setting up a screen lock recovers.
  unavailable,

  /// Too many failed attempts; the system has paused authentication.
  lockedOut,

  /// The check failed unexpectedly. Trying again may work.
  error,
}
