import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_update_result.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'update_dialog.dart';

/// Centralised service that shows the app-update dialog via the root
/// Navigator key, avoiding the stale/Below-Navigator BuildContext problem.
class UpdateDialogService {
  UpdateDialogService._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Whether an update dialog is currently visible (single-dialog guard).
  static bool _isShowing = false;

  /// Reset the dialog guard.  Only for tests.
  @visibleForTesting
  static void resetGuard() => _isShowing = false;

  /// Show the update dialog if the root Navigator is mounted and no
  /// dialog is already visible.
  static void show(AppUpdateResult result) {
    if (_isShowing) return;

    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null || !navigatorState.mounted) return;

    final context = navigatorState.context;

    _isShowing = true;

    AppDialog.show<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(result: result),
    ).whenComplete(() {
      _isShowing = false;
    });
  }

  /// Launch the GitHub release URL in an external browser.
  /// Can be used by the Settings screen or anywhere else that needs
  /// to open the latest release without showing the dialog first.
  static Future<void> viewRelease(AppUpdateResult result) async {
    final url = result.releaseUrl.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Swallow — the caller should not crash for an external URL failure.
    }
  }
}
