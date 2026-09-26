import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';

/// Displays app name, version, a privacy summary and the licence page link.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  static const _privacy = InfoContent(
    title: 'Privacy',
    whatIsThis:
        'Your budgets, expenses, bills and settings are stored only on this '
        'device, and everything works without an internet connection.',
    additionalNotes:
        '• No account is needed\n'
        '• No personal or financial data is collected or sent anywhere\n'
        '• The only network request is the optional "Check for updates", '
        'which asks GitHub for the latest release version',
  );

  /// Read once per process: a new future on every rebuild (theme change,
  /// settings reload) would blank the version to "…" and fill it in again.
  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final appName = info?.appName ?? 'Monivo';
        final version = info == null
            ? '…'
            : 'v${info.version}'
                  '${info.buildNumber.isNotEmpty ? ' (${info.buildNumber})' : ''}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: 'App', value: appName),
            const SizedBox(height: AppSpacing.sm),
            _Row(label: 'Version', value: version),
            const SizedBox(height: AppSpacing.smd),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: AppSizes.iconSm,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'All data stays on this device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const InfoIcon(content: _privacy),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: appName,
                  applicationVersion: info?.version,
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Open source licenses'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
