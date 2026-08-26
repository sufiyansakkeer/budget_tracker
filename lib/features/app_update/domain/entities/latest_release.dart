/// Represents the latest release fetched from GitHub.
class LatestRelease {
  final String version;
  final String title;
  final String releaseUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  const LatestRelease({
    required this.version,
    required this.title,
    required this.releaseUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}
