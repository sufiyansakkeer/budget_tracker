/// Data model for parsing the GitHub releases/latest API response.
class GithubReleaseModel {
  final String tagName;
  final String name;
  final String htmlUrl;
  final String body;
  final DateTime publishedAt;
  final bool prerelease;
  final bool draft;

  const GithubReleaseModel({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.body,
    required this.publishedAt,
    required this.prerelease,
    required this.draft,
  });

  /// Parses a JSON map into a [GithubReleaseModel].
  ///
  /// Throws [FormatException] if required fields are missing or malformed.
  factory GithubReleaseModel.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String?;
    if (tagName == null || tagName.isEmpty) {
      throw const FormatException('Missing or empty tag_name');
    }

    final htmlUrl = json['html_url'] as String?;
    if (htmlUrl == null || htmlUrl.isEmpty) {
      throw const FormatException('Missing or empty html_url');
    }

    final publishedAtStr = json['published_at'] as String?;
    DateTime publishedAt;
    try {
      publishedAt = DateTime.parse(publishedAtStr ?? '');
    } catch (_) {
      publishedAt = DateTime.now();
    }

    return GithubReleaseModel(
      tagName: tagName,
      name: (json['name'] as String?) ?? tagName,
      htmlUrl: htmlUrl,
      body: (json['body'] as String?) ?? '',
      publishedAt: publishedAt,
      prerelease: json['prerelease'] as bool? ?? false,
      draft: json['draft'] as bool? ?? false,
    );
  }

  /// Normalized version string with the leading 'v' prefix stripped.
  String get normalizedVersion {
    var v = tagName.trim();
    if (v.toLowerCase().startsWith('v')) {
      v = v.substring(1);
    }
    return v;
  }
}
