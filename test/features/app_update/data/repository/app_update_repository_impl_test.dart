import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:monivo/features/app_update/data/datasources/github_release_remote_datasource.dart';
import 'package:monivo/features/app_update/data/models/github_release_model.dart';
import 'package:monivo/features/app_update/data/repository/app_update_repository_impl.dart';
import 'package:monivo/features/app_update/domain/repository/app_update_repository.dart';

@GenerateMocks([GithubReleaseRemoteDataSource])
import 'app_update_repository_impl_test.mocks.dart';

void main() {
  late MockGithubReleaseRemoteDataSource mockDataSource;
  late AppUpdateRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockGithubReleaseRemoteDataSource();
    repository = AppUpdateRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('getLatestRelease', () {
    test('returns LatestRelease on successful response', () async {
      final model = GithubReleaseModel(
        tagName: 'v1.2.0',
        name: 'Release 1.2.0',
        htmlUrl: 'https://github.com/test/repo/releases/tag/v1.2.0',
        body: 'Bug fixes',
        publishedAt: DateTime(2025, 1, 15),
        prerelease: false,
        draft: false,
      );

      when(mockDataSource.getLatestRelease()).thenAnswer((_) async => model);

      final result = await repository.getLatestRelease();

      expect(result.version, '1.2.0');
      expect(result.title, 'Release 1.2.0');
      expect(result.releaseUrl, model.htmlUrl);
      expect(result.releaseNotes, 'Bug fixes');
      verify(mockDataSource.getLatestRelease()).called(1);
    });

    test('converts tagName v prefix to normalized version', () async {
      final model = GithubReleaseModel(
        tagName: 'v2.0.0',
        name: 'Release 2.0.0',
        htmlUrl: 'https://example.com',
        body: '',
        publishedAt: DateTime(2025, 1, 1),
        prerelease: false,
        draft: false,
      );

      when(mockDataSource.getLatestRelease()).thenAnswer((_) async => model);

      final result = await repository.getLatestRelease();
      expect(result.version, '2.0.0');
    });

    test('throws AppUpdateException on GithubApiException', () async {
      when(mockDataSource.getLatestRelease()).thenThrow(
        const GithubApiException(
          message: 'Unable to reach GitHub.',
          statusCode: null,
        ),
      );

      expect(
        () => repository.getLatestRelease(),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('throws AppUpdateException on unexpected error', () async {
      when(
        mockDataSource.getLatestRelease(),
      ).thenThrow(Exception('something unexpected'));

      expect(
        () => repository.getLatestRelease(),
        throwsA(isA<AppUpdateException>()),
      );
    });
  });
}
