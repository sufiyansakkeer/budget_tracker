import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/github_config.dart';
import '../models/github_release_model.dart';
import 'github_release_remote_datasource.dart';

/// Fetches the latest release from the GitHub REST API.
class GithubReleaseRemoteDataSourceImpl
    implements GithubReleaseRemoteDataSource {
  final http.Client _client;

  GithubReleaseRemoteDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<GithubReleaseModel> getLatestRelease() async {
    final uri = Uri.parse(GitHubConfig.latestReleaseEndpoint);

    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(GitHubConfig.requestTimeout);
    } catch (e) {
      throw const GithubApiException(
        message: 'Unable to reach GitHub. Please check your connection.',
      );
    }

    if (response.statusCode != 200) {
      throw GithubApiException(
        message: _messageForStatusCode(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return GithubReleaseModel.fromJson(json);
    } catch (_) {
      throw const GithubApiException(
        message: 'Received an unexpected response from GitHub.',
      );
    }
  }

  String _messageForStatusCode(int code) {
    switch (code) {
      case 404:
        return 'Release information not found.';
      case 403:
      case 429:
        return 'GitHub rate limit exceeded. Please try again later.';
      default:
        if (code >= 500) {
          return 'GitHub server error. Please try again later.';
        }
        return 'Unexpected error (HTTP $code).';
    }
  }
}
