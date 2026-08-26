/// Centralized GitHub API configuration for the app update checker.
///
/// All GitHub-related constants are defined here to avoid scattering
/// repository information throughout the codebase.
class GitHubConfig {
  GitHubConfig._();

  static const String owner = 'sufiyansakkeer';
  static const String repository = 'budget_tracker';

  static const String latestReleaseEndpoint =
      'https://api.github.com/repos/$owner/$repository/releases/latest';

  static const Duration requestTimeout = Duration(seconds: 10);
}
