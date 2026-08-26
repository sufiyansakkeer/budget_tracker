import '../../domain/entities/latest_release.dart';
import '../../domain/repository/app_update_repository.dart';
import '../datasources/github_release_remote_datasource.dart';
import '../models/github_release_model.dart';

/// Bridges the remote GitHub data source to the domain layer.
class AppUpdateRepositoryImpl implements AppUpdateRepository {
  final GithubReleaseRemoteDataSource _remoteDataSource;

  AppUpdateRepositoryImpl({
    required GithubReleaseRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<LatestRelease> getLatestRelease() async {
    try {
      final model = await _remoteDataSource.getLatestRelease();
      return _toDomain(model);
    } on GithubApiException catch (e) {
      throw AppUpdateException(e.message);
    } catch (e) {
      throw const AppUpdateException(
        'An unexpected error occurred while checking for updates.',
      );
    }
  }

  LatestRelease _toDomain(GithubReleaseModel model) {
    return LatestRelease(
      version: model.normalizedVersion,
      title: model.name,
      releaseUrl: model.htmlUrl,
      releaseNotes: model.body,
      publishedAt: model.publishedAt,
    );
  }
}
