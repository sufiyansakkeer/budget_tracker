import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/app_update_result.dart';

/// Shows a Material 3 update dialog when a new release is available.
class UpdateDialog extends StatelessWidget {
  final AppUpdateResult result;

  const UpdateDialog({super.key, required this.result});

  /// Convenience method to show the dialog via Navigator.
  ///
  /// The [context] must be below [MaterialApp] so that [MaterialLocalizations]
  /// is available.
  static Future<void> show(BuildContext context, AppUpdateResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            _UpdateButtons(releaseUrl: result.releaseUrl),
          ],
        ),
      ),
    );
  }

  /// Strips leading markdown and cleans up raw release notes for display.
  String _cleanReleaseNotes(String notes) {
    var cleaned = notes.trim();
    // Remove leading markdown headers
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Trim to a reasonable preview length
    if (cleaned.length > 500) {
      cleaned = '${cleaned.substring(0, 500)}…';
    }
    return cleaned;
  }
}

class _UpdateButtons extends StatefulWidget {
  final String releaseUrl;

  const _UpdateButtons({required this.releaseUrl});

  @override
  State<_UpdateButtons> createState() => _UpdateButtonsState();
}

class _UpdateButtonsState extends State<_UpdateButtons> {
  bool _isLaunching = false;

  Future<void> _launchReleaseUrl(BuildContext context) async {
    if (_isLaunching) return;

    final url = widget.releaseUrl.trim();
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

    // Capture references before the async gap so they remain valid.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (launched) {
        navigator.pop();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Unable to open the release page.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to open the release page.'),
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
    return Row(
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
            onPressed: _isLaunching ? null : () => _launchReleaseUrl(context),
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
    );
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
