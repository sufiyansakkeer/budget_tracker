import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/app_update/data/models/github_release_model.dart';

void main() {
  group('GithubReleaseModel.fromJson', () {
    test('parses valid JSON', () {
      final json = {
        'tag_name': 'v1.2.0',
        'name': 'Release 1.2.0',
        'html_url': 'https://github.com/test/repo/releases/tag/v1.2.0',
        'body': 'Bug fixes',
        'published_at': '2025-01-15T10:00:00Z',
        'prerelease': false,
        'draft': false,
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.tagName, 'v1.2.0');
      expect(model.name, 'Release 1.2.0');
      expect(model.htmlUrl, 'https://github.com/test/repo/releases/tag/v1.2.0');
      expect(model.body, 'Bug fixes');
      expect(model.prerelease, false);
      expect(model.draft, false);
    });

    test('normalizedVersion strips v prefix', () {
      final json = {
        'tag_name': 'v1.2.0',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.normalizedVersion, '1.2.0');
    });

    test('normalizedVersion handles tag without v prefix', () {
      final json = {
        'tag_name': '1.3.0',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.normalizedVersion, '1.3.0');
    });

    test('defaults name to tagName when name is missing', () {
      final json = {
        'tag_name': 'v2.0.0',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.name, 'v2.0.0');
    });

    test('defaults body to empty string when body is missing', () {
      final json = {
        'tag_name': 'v1.0.0',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.body, '');
    });

    test('throws FormatException when tag_name is missing', () {
      final json = {
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
      };

      expect(() => GithubReleaseModel.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when tag_name is empty', () {
      final json = {
        'tag_name': '',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
      };

      expect(() => GithubReleaseModel.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when html_url is missing', () {
      final json = {
        'tag_name': 'v1.0.0',
        'published_at': '2025-01-01T00:00:00Z',
      };

      expect(() => GithubReleaseModel.fromJson(json), throwsFormatException);
    });

    test('handles missing published_at gracefully', () {
      final json = {'tag_name': 'v1.0.0', 'html_url': 'https://example.com'};

      final model = GithubReleaseModel.fromJson(json);
      expect(model.publishedAt, isA<DateTime>());
    });

    test('parses prerelease flag', () {
      final json = {
        'tag_name': 'v2.0.0-beta',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
        'prerelease': true,
        'draft': false,
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.prerelease, true);
    });

    test('parses draft flag', () {
      final json = {
        'tag_name': 'v2.0.0',
        'html_url': 'https://example.com',
        'published_at': '2025-01-01T00:00:00Z',
        'prerelease': false,
        'draft': true,
      };

      final model = GithubReleaseModel.fromJson(json);
      expect(model.draft, true);
    });
  });
}
