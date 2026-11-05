import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/platform/system_ui_session.dart';
import '../../domain/entities/settings_failure.dart';
import '../../domain/services/backup_service.dart';
import '../bloc/settings_bloc.dart';
import 'reset_confirmation_dialog.dart';

/// Restore's first half, shared by Settings and onboarding's Welcome: pick
/// a backup, read what it holds, and ask before anything is replaced.
abstract final class RestoreBackupFlow {
  /// The picked backup's path once the user confirmed, or null. A file that
  /// isn't a usable backup is refused before the question, and
  /// [onRefused] says why.
  static Future<String?> pickAndConfirm(
    BuildContext context, {
    required Future<SettingsResult<BackupSummary>> Function(String path)
    preview,
    required void Function(String message) onRefused,
    @visibleForTesting Future<String?> Function()? pickFile,
  }) async {
    final path = await (pickFile ?? _pickBackup)();
    if (path == null || !context.mounted) return null;
    final result = await preview(path);
    if (!context.mounted) return null;
    switch (result) {
      case SettingsError(:final failure):
        onRefused(SettingsBloc.restoreErrorMessage(failure));
        return null;
      case SettingsSuccess(data: final summary):
        final confirmed = await ResetConfirmationDialog.show(
          context,
          title: 'Restore this backup?',
          message:
              '${describe(summary)}\n\n'
              'Your current budgets, expenses, bills and settings will be '
              'replaced with this backup. This cannot be undone.',
          confirmLabel: 'Restore',
          icon: Icons.settings_backup_restore_rounded,
          isDestructive: true,
        );
        return confirmed ? path : null;
    }
  }

  /// "Backup from 3 Oct 2026, 2:30 PM · 3 budgets · 412 expenses · 2 bills".
  @visibleForTesting
  static String describe(BackupSummary summary) {
    String count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';
    final createdAt = summary.createdAt;
    return [
      createdAt == null
          ? 'Backup'
          : 'Backup from ${DateFormat('d MMM yyyy, h:mm a').format(createdAt)}',
      count(summary.budgets, 'budget'),
      count(summary.expenses, 'expense'),
      count(summary.bills, 'bill'),
    ].join(' · ');
  }

  static Future<String?> _pickBackup() async {
    // The picker takes the foreground; the session keeps the app lock from
    // treating it as leaving the app.
    final result = await SystemUiSession.run(
      () => FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      ),
    );
    return result?.files.single.path;
  }
}
