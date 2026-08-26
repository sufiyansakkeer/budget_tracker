import '../models/github_release_model.dart';

/// Contract for fetching the latest GitHub release information.
abstract class GithubReleaseRemoteDataSource {
  /// Fetches the latest non-draft, non-prerelease from GitHub.
  ///
  /// Throws [GithubApiException] on network or API errors.
  Future<GithubReleaseModel> getLatestRelease();
}

/// Typed exception for GitHub API errors.
class GithubApiException implements Exception {
  final String message;
  final int? statusCode;

  const GithubApiException({required this.message, this.statusCode});

  @override
  String toString() => 'GithubApiException: $message (status: $statusCode)';
}
