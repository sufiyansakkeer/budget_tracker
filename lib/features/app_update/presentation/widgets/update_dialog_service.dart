import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/app_update_result.dart';

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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialogBody(
        result: result,
        onDismissed: () => _isShowing = false,
      ),
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

// ---------------------------------------------------------------------------
// Private dialog widget
// ---------------------------------------------------------------------------

class _UpdateDialogBody extends StatefulWidget {
  final AppUpdateResult result;
  final VoidCallback onDismissed;

  const _UpdateDialogBody({required this.result, required this.onDismissed});

  @override
  State<_UpdateDialogBody> createState() => _UpdateDialogBodyState();
}

class _UpdateDialogBodyState extends State<_UpdateDialogBody> {
  bool _isLaunching = false;

  Future<void> _launchReleaseUrl() async {
    if (_isLaunching) return;

    final url = widget.result.releaseUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No update URL available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid update URL.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLaunching = true);

    // Capture references before the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (launched) {
        nav.pop();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Unable to open the update page.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to open the update page.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final result = widget.result;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              'Update Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Description
            Text(
              'A new version of Smart Budget Tracker is available.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Version info
            _VersionRow(
              label: 'Current version',
              version: 'v${result.currentVersion}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _VersionRow(
              label: 'Latest version',
              version: 'v${result.latestVersion}',
            ),
            const SizedBox(height: AppSpacing.lg),

            // Release notes preview
            if (result.releaseNotes.isNotEmpty) ...[
              Text(
                "What's new?",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    _cleanReleaseNotes(result.releaseNotes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLaunching ? null : () => _launchReleaseUrl(),
                    child: _isLaunching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Strips leading markdown and cleans up raw release notes for display.
  String _cleanReleaseNotes(String notes) {
    var cleaned = notes.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    if (cleaned.length > 500) {
      cleaned = '${cleaned.substring(0, 500)}…';
    }
    return cleaned;
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String version;

  const _VersionRow({required this.label, required this.version});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          version,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
