import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Export, import, backup and restore actions, grouped in labelled rows.
class DataManagementCard extends StatelessWidget {
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportJson;
  final VoidCallback? onImportCsv;
  final VoidCallback? onImportJson;
  final VoidCallback? onBackup;
  final VoidCallback? onRestore;

  /// Runs the integrity check. Hidden when null.
  final VoidCallback? onCheckIntegrity;
  final bool isBusy;

  const DataManagementCard({
    super.key,
    this.onExportCsv,
    this.onExportJson,
    this.onImportCsv,
    this.onImportJson,
    this.onBackup,
    this.onRestore,
    this.onCheckIntegrity,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionRow(
          icon: Icons.ios_share_rounded,
          title: 'Export',
          description: 'Share your expenses as a spreadsheet or JSON file.',
          actions: [
            _Action('CSV', Icons.table_chart_outlined, onExportCsv),
            _Action('JSON', Icons.data_object_rounded, onExportJson),
          ],
          busy: isBusy,
        ),
        const Divider(height: AppSpacing.lg),
        _ActionRow(
          icon: Icons.download_rounded,
          title: 'Import',
          description: 'Merge expenses from a file into your records.',
          actions: [
            _Action('CSV', Icons.table_chart_outlined, onImportCsv),
            _Action('JSON', Icons.data_object_rounded, onImportJson),
          ],
          busy: isBusy,
        ),
        const Divider(height: AppSpacing.lg),
        _ActionRow(
          icon: Icons.backup_outlined,
          title: 'Backup & restore',
          description: 'A full copy of budgets, expenses, bills and settings.',
          actions: [
            _Action('Back up', Icons.cloud_upload_outlined, onBackup),
            _Action(
              'Restore',
              Icons.settings_backup_restore_rounded,
              onRestore,
            ),
          ],
          busy: isBusy,
        ),
        if (onCheckIntegrity != null) ...[
          const Divider(height: AppSpacing.lg),
          _ActionRow(
            icon: Icons.health_and_safety_outlined,
            title: 'Database health',
            description:
                'Looks for expenses, bills or budgets that no longer link '
                'up correctly.',
            actions: [
              _Action(
                'Check now',
                Icons.fact_check_outlined,
                onCheckIntegrity,
                key: const Key('checkIntegrityButton'),
              ),
            ],
            busy: isBusy,
          ),
        ],
        if (isBusy) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(minHeight: AppSizes.progressThin),
        ],
      ],
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? key;
  const _Action(this.label, this.icon, this.onPressed, {this.key});
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<_Action> actions;
  final bool busy;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: AppSizes.iconMd,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: actions[i].key,
                    onPressed: busy ? null : actions[i].onPressed,
                    icon: Icon(actions[i].icon, size: AppSizes.iconSm + 2),
                    label: Text(
                      actions[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
