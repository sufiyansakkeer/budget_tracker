import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../settings/presentation/widgets/settings_section.dart';
import '../../domain/entities/app_update_result.dart';
import '../bloc/app_update_bloc.dart';
import '../bloc/app_update_event.dart';
import '../bloc/app_update_state.dart';
import 'update_dialog_service.dart';

/// Settings section for App Updates.
///
/// Reads [AppUpdateBloc] from the widget tree. Place it inside a
/// [BlocProvider<AppUpdateBloc>] higher up.
class AppUpdateSection extends StatelessWidget {
  const AppUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSection(
      title: 'Updates',
      icon: Icons.system_update_outlined,
      description:
          'Compares your installed version with the latest GitHub release. '
          'Nothing installs automatically.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: BlocBuilder<AppUpdateBloc, AppUpdateState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VersionRow(state: state),
                  const SizedBox(height: AppSpacing.smd),
                  AnimatedSize(
                    duration: AppMotion.respectReducedMotion(
                      context,
                      AppMotion.standard,
                    ),
                    curve: AppMotion.standardCurve,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: AppMotion.respectReducedMotion(
                        context,
                        AppMotion.standard,
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(state.runtimeType),
                        child: _StatusContent(state: state, theme: theme),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  final AppUpdateState state;
  const _VersionRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String version = '—';
    if (state is AppUpdateAvailable) {
      version = 'v${(state as AppUpdateAvailable).result.currentVersion}';
    } else if (state is AppUpdateUpToDate) {
      version = 'v${(state as AppUpdateUpToDate).result.currentVersion}';
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            'Current Version',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(version, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _StatusContent extends StatelessWidget {
  final AppUpdateState state;
  final ThemeData theme;
  const _StatusContent({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (state is AppUpdateChecking) {
      return Row(
        children: [
          const SizedBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
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
      return _UpdateAvailableContent(
        result: (state as AppUpdateAvailable).result,
      );
    }

    if (state is AppUpdateUpToDate) {
      final result = (state as AppUpdateUpToDate).result;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: AppSizes.iconSm + 2,
                color: colors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "You're up to date",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your installed version is the latest version released on GitHub'
            '${result.latestVersion.isNotEmpty ? ' (v${result.latestVersion})' : ''}.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.read<AppUpdateBloc>().add(
                const AppUpdateManualCheck(),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check again'),
            ),
          ),
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
                Icons.error_outline_rounded,
                size: AppSizes.iconSm + 2,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "Couldn't check for updates.",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The GitHub release check needs an internet connection. '
            'Everything else in the app keeps working offline.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.smd),
          OutlinedButton.icon(
            onPressed: () =>
                context.read<AppUpdateBloc>().add(const AppUpdateManualCheck()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      );
    }

    // Initial / unknown state.
    return OutlinedButton.icon(
      onPressed: () =>
          context.read<AppUpdateBloc>().add(const AppUpdateManualCheck()),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Check for Updates'),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No update page is available.')),
        );
      return;
    }
    setState(() => _isLaunching = true);
    try {
      await UpdateDialogService.viewRelease(widget.result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Unable to open the release page.')),
          );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
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
              Icons.new_releases_rounded,
              size: AppSizes.iconSm + 2,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Update Available',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
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
        const SizedBox(height: AppSpacing.smd),
        FilledButton.icon(
          onPressed: _isLaunching ? null : _launchReleaseUrl,
          icon: _isLaunching
              ? const SizedBox(
                  width: AppSizes.iconSm,
                  height: AppSizes.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new_rounded),
          label: const Text('View Update'),
        ),
      ],
    );
  }
}
