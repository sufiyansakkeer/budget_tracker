import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_spacing.dart';

/// Displays app name, version, build number, and a privacy notice.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version ?? '1.0.0';
        // final buildNumber = info?.buildNumber ?? '1';
        final appName = info?.appName ?? 'Smart Monivo';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: 'App Name', value: appName),
            const SizedBox(height: AppSpacing.sm),
            // _Row(label: 'Version', value: version),
            // const SizedBox(height: AppSpacing.sm),
            // _Row(label: 'Build Number', value: buildNumber),
            // const SizedBox(height: AppSpacing.sm),
            // const _Row(label: 'Database Version', value: '2'),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Privacy Notice',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'All your data — expenses, budgets, bills, and settings — are '
              'stored locally on your device. No data is collected, shared, '
              'or transmitted to any server. The only feature that requires '
              'internet access is checking for app updates.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Licenses',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: appName,
                applicationVersion: version,
              ),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Open Source Licenses'),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
