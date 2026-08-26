import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/app_update_result.dart';
import '../bloc/app_update_bloc.dart';
import '../bloc/app_update_event.dart';
import '../bloc/app_update_state.dart';
import 'update_dialog_service.dart';

/// A self-contained Settings section for App Updates.
///
/// Reads [AppUpdateBloc] from the widget tree. Place it inside a
/// [BlocProvider<AppUpdateBloc>] higher up.
class AppUpdateSection extends StatelessWidget {
  const AppUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.system_update_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'App Updates',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: BlocBuilder<AppUpdateBloc, AppUpdateState>(
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentVersion(context, state),
                    const SizedBox(height: AppSpacing.md),
                    _buildStatusContent(context, state),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildCurrentVersion(BuildContext context, AppUpdateState state) {
    final theme = Theme.of(context);
    // Use the version from the state if available, otherwise show a placeholder.
    String version = '—';
    if (state is AppUpdateAvailable) {
      version = 'v${state.result.currentVersion}';
    } else if (state is AppUpdateUpToDate) {
      version = 'v${state.result.currentVersion}';
    } else if (state is AppUpdateCheckFailed) {
      version = '—';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Current Version',
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

  Widget _buildStatusContent(BuildContext context, AppUpdateState state) {
    final theme = Theme.of(context);

    if (state is AppUpdateChecking) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Checking for updates…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (state is AppUpdateAvailable) {
      return _UpdateAvailableContent(result: state.result);
    }

    if (state is AppUpdateUpToDate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                "You're up to date",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "You're using the latest version of Smart Budget Tracker.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.result.latestVersion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'v${state.result.latestVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      );
    }

    if (state is AppUpdateCheckFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "Couldn't check for updates.",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Please check your internet connection and try again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<AppUpdateBloc>().add(const AppUpdateManualCheck());
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    // Initial or unknown state — show check button.
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<AppUpdateBloc>().add(const AppUpdateManualCheck());
        },
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Check for Updates'),
      ),
    );
  }
}

/// Shows the "update available" state with a View Update button.
class _UpdateAvailableContent extends StatefulWidget {
  final AppUpdateResult result;

  const _UpdateAvailableContent({required this.result});

  @override
  State<_UpdateAvailableContent> createState() =>
      _UpdateAvailableContentState();
}

class _UpdateAvailableContentState extends State<_UpdateAvailableContent> {
  bool _isLaunching = false;

  Future<void> _launchReleaseUrl() async {
    if (_isLaunching) return;

    final url = widget.result.releaseUrl.trim();
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No update URL available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLaunching = true);

    try {
      await UpdateDialogService.viewRelease(widget.result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the release page.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.new_releases_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Update Available',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Latest version: v${result.latestVersion}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isLaunching ? null : _launchReleaseUrl,
            icon: _isLaunching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.open_in_new, size: 18),
            label: const Text('View Update'),
          ),
        ),
      ],
    );
  }
}
