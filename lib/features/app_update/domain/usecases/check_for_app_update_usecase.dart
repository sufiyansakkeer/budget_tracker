import 'dart:developer' as developer;

import 'package:package_info_plus/package_info_plus.dart';

import '../entities/app_update_result.dart';
import '../entities/latest_release.dart';
import '../entities/update_status.dart';
import '../repository/app_update_repository.dart';

/// Fetches the latest GitHub release, compares it with the installed app
/// version, and returns a structured [AppUpdateResult].
class CheckForAppUpdateUseCase {
  final AppUpdateRepository _repository;

  CheckForAppUpdateUseCase({required AppUpdateRepository repository})
    : _repository = repository;

  /// Runs the update check. Reading the installed version can fail too;
  /// that ends the check as failed rather than leaving it running.
  Future<AppUpdateResult> call() async {
    final String installedVersion;
    try {
      installedVersion = (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      developer.log(
        '[AppUpdate] Could not read the installed version: $e',
        name: 'AppUpdate',
      );
      return const AppUpdateResult(
        status: UpdateStatus.checkFailed,
        currentVersion: '',
        latestVersion: '',
      );
    }
    final currentVersion = _normalizeVersion(installedVersion);

    LatestRelease latestRelease;
    try {
      latestRelease = await _repository.getLatestRelease();
    } on AppUpdateException catch (e) {
      return AppUpdateResult(
        status: UpdateStatus.checkFailed,
        currentVersion: installedVersion,
        latestVersion: '',
        errorMessage: e.message,
      );
    }

    final latestVersion = latestRelease.version;
    final comparison = compareVersions(currentVersion, latestVersion);

    UpdateStatus status;
    switch (comparison) {
      case < 0:
        status = UpdateStatus.updateAvailable;
        break;
      case 0:
        status = UpdateStatus.upToDate;
        break;
      default:
        status = UpdateStatus.newerVersion;
    }

    return AppUpdateResult(
      status: status,
      currentVersion: installedVersion,
      latestVersion: latestVersion,
      releaseUrl: latestRelease.releaseUrl,
      releaseTitle: latestRelease.title,
      releaseNotes: latestRelease.releaseNotes,
      publishedAt: latestRelease.publishedAt,
    );
  }

  /// Strips the leading 'v' prefix and build metadata (+N).
  static String _normalizeVersion(String version) {
    var v = version.trim();
    if (v.toLowerCase().startsWith('v')) {
      v = v.substring(1);
    }
    // Strip build metadata (e.g. 1.2.0+15 → 1.2.0)
    final plusIndex = v.indexOf('+');
    if (plusIndex != -1) {
      v = v.substring(0, plusIndex);
    }
    return v;
  }

  /// Compares two semantic version strings.
  ///
  /// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
  ///
  /// Handles versions like "1.0.0", "1.10.0", "v1.2.3", etc.
  static int compareVersions(String a, String b) {
    final normA = _normalizeVersion(a);
    final normB = _normalizeVersion(b);

    final partsA = normA.split('.');
    final partsB = normB.split('.');
    final length = partsA.length > partsB.length
        ? partsA.length
        : partsB.length;

    for (var i = 0; i < length; i++) {
      final numA = i < partsA.length ? int.tryParse(partsA[i]) ?? 0 : 0;
      final numB = i < partsB.length ? int.tryParse(partsB[i]) ?? 0 : 0;
      if (numA != numB) {
        return numA.compareTo(numB);
      }
    }
    return 0;
  }
}
