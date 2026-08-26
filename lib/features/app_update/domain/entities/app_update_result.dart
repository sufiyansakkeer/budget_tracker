import 'update_status.dart';

/// Contains the full result of an app update check, including all
/// information needed by the presentation layer.
class AppUpdateResult {
  final UpdateStatus status;
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String releaseTitle;
  final String releaseNotes;
  final DateTime? publishedAt;
  final String? errorMessage;

  const AppUpdateResult({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseUrl = '',
    this.releaseTitle = '',
    this.releaseNotes = '',
    this.publishedAt,
    this.errorMessage,
  });

  bool get isUpdateAvailable => status == UpdateStatus.updateAvailable;
}
