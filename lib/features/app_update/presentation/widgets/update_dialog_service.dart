import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_update_result.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'update_dialog.dart';
import 'update_prompt_policy.dart';

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

  /// Shows the dialog after the launch-time check, but only when the user
  /// is on Home with nothing else to do first. Never during onboarding, on
  /// a screen a widget or notification opened, or over a widget launch;
  /// never again for a version the user skipped, or within a day of
  /// "Later".
  static Future<void> showOnLaunch(
    AppUpdateResult result, {
    @visibleForTesting Future<bool> Function()? openedFromWidget,
  }) async {
    if (!await UpdatePromptPolicy.allows(result.latestVersion)) return;
    if (await (openedFromWidget ?? _openedFromWidget)()) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    // Plain test apps have no router; the app always has one.
    final location = GoRouter.maybeOf(context)?.state.uri.path;
    if (location != null && location != AppRouter.homePath) return;
    show(result);
  }

  static Future<bool> _openedFromWidget() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget() != null;
    } catch (e) {
      debugPrint('[error] Reading the widget launch: $e');
      return false;
    }
  }

  /// Launch the GitHub release URL in an external browser.
  /// Can be used by the Settings screen or anywhere else that needs
  /// to open the latest release without showing the dialog first.
  ///
  /// Returns false when there is no usable link or the page could not be
  /// opened, so the caller can say so.
  static Future<bool> viewRelease(AppUpdateResult result) async {
    final uri = Uri.tryParse(result.releaseUrl.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[error] Opening the release page: $e');
      return false;
    }
  }
}
