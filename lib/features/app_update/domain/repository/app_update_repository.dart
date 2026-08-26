import '../entities/latest_release.dart';

/// Contract for the app update repository.
///
/// The presentation layer must not know that data comes from GitHub.
abstract class AppUpdateRepository {
  /// Fetches the latest release information.
  ///
  /// Returns [LatestRelease] on success.
  /// Throws [AppUpdateException] on failure.
  Future<LatestRelease> getLatestRelease();
}

/// Typed exception for app update errors.
class AppUpdateException implements Exception {
  final String message;

  const AppUpdateException(this.message);

  @override
  String toString() => 'AppUpdateException: $message';
}
