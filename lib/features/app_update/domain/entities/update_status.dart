/// The result status of an app update check.
enum UpdateStatus {
  /// An update is available.
  updateAvailable,

  /// The app is already on the latest version.
  upToDate,

  /// The installed version is newer than the latest release.
  newerVersion,

  /// The update check failed (network error, API error, etc.).
  checkFailed,
}
