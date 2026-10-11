import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../domain/services/file_delivery_service.dart';

/// Asks where a new backup goes: saved to a folder on this device, or
/// shared to another app. Returns the choice, or null when dismissed.
///
/// A backup has to leave the app to be any use: the app's own storage is
/// invisible to the system file picker Restore opens, and an uninstall
/// removes it.
class BackupDestinationSheet extends StatelessWidget {
  const BackupDestinationSheet({super.key});

  static Future<FileDestination?> show(BuildContext context) =>
      AppBottomSheet.show<FileDestination>(
        context: context,
        builder: (_) => const BackupDestinationSheet(),
      );

  static const _options = [
    (
      destination: FileDestination.device,
      icon: Icons.save_alt_rounded,
      title: 'Save to this device',
      detail:
          'Choose a folder, such as Downloads or Files. Restore can open '
          'it from there.',
    ),
    (
      destination: FileDestination.share,
      icon: Icons.ios_share_rounded,
      title: 'Share',
      detail:
          'Send it to Google Drive, email or another app, to keep a copy '
          'off this phone.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHeader(
            title: 'Back up',
            subtitle:
                'One file with all your budgets, expenses, bills and '
                'settings. Keep it somewhere safe.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: AppGroupedList(
              dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
              children: [
                for (final option in _options)
                  AppListRow(
                    key: Key('backupTo_${option.destination.name}'),
                    leading: IconTile(
                      icon: option.icon,
                      color: theme.colorScheme.primary,
                      size: AppSizes.avatarSm,
                    ),
                    title: option.title,
                    subtitleWidget: Text(option.detail, style: muted),
                    semanticLabel: '${option.title}. ${option.detail}',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.of(context).pop(option.destination),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
