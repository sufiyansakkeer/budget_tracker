import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// A card containing buttons for export, import, backup, and restore actions.
class DataManagementCard extends StatelessWidget {
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportJson;
  final VoidCallback? onImportCsv;
  final VoidCallback? onImportJson;
  final VoidCallback? onBackup;
  final VoidCallback? onRestore;
  final bool isBusy;

  const DataManagementCard({
    super.key,
    this.onExportCsv,
    this.onExportJson,
    this.onImportCsv,
    this.onImportJson,
    this.onBackup,
    this.onRestore,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Export & Share',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.table_chart_outlined,
                label: 'CSV',
                onPressed: isBusy ? null : onExportCsv,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionButton(
                icon: Icons.data_object_outlined,
                label: 'JSON',
                onPressed: isBusy ? null : onExportJson,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Import',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.upload_outlined,
                label: 'Import CSV',
                onPressed: isBusy ? null : onImportCsv,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionButton(
                icon: Icons.upload_file_outlined,
                label: 'Import JSON',
                onPressed: isBusy ? null : onImportJson,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Backup & Restore',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.backup_outlined,
                label: 'Backup',
                onPressed: isBusy ? null : onBackup,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionButton(
                icon: Icons.restore_outlined,
                label: 'Restore',
                onPressed: isBusy ? null : onRestore,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      ),
    );
  }
}
