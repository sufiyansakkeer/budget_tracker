import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/di/injection.dart' as di;
import '../../../app_update/presentation/bloc/app_update_bloc.dart';
import '../../../app_update/presentation/widgets/app_update_section.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/entities/theme_mode_entity.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';
import '../widgets/about_card.dart';
import '../widgets/biometric_tile.dart';
import '../widgets/currency_selector.dart';
import '../widgets/data_management_card.dart';
import '../widgets/notification_time_tile.dart';
import '../widgets/notification_toggle.dart';
import '../widgets/reset_confirmation_dialog.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/theme_selector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(const SettingsLoadEvent());
  }

  Future<String?> _pickFile({required bool json}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: json ? ['json'] : ['csv'],
      withData: false,
    );
    return result?.files.single.path;
  }

  void _showCurrencyPicker(BuildContext context, String selectedCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: CurrencySelector(
            selectedCode: selectedCode,
            onSelected: (CurrencyEntity currency) {
              context.read<SettingsBloc>().add(
                SettingsUpdateCurrencyEvent(
                  code: currency.code,
                  symbol: currency.symbol,
                ),
              );
              // Update currency provider for immediate UI change
              di.getIt<CurrencyProvider>().updateCurrency(
                currency.code,
                currency.symbol,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndRestore(BuildContext context, SettingsBloc bloc) async {
    final path = await _pickFile(json: true);
    if (path == null) return;
    if (!context.mounted) return;

    final confirm = await ResetConfirmationDialog.show(
      context,
      title: 'Restore Backup?',
      message:
          'This will replace your current data with the backup contents. '
          'This cannot be undone. Continue?',
      confirmLabel: 'Restore',
      icon: Icons.restore,
      isDestructive: false,
    );
    if (!confirm) return;
    bloc.add(SettingsRestoreEvent(path));
  }

  Future<void> _pickAndImport(
    BuildContext context,
    SettingsBloc bloc, {
    required bool json,
  }) async {
    final path = await _pickFile(json: json);
    if (path == null) return;
    if (!context.mounted) return;

    final confirm = await ResetConfirmationDialog.show(
      context,
      title: 'Import Data?',
      message:
          'Imported ${json ? 'JSON' : 'CSV'} data will be merged into '
          'your existing records. Continue?',
      confirmLabel: 'Import',
      icon: Icons.upload_file,
      isDestructive: false,
    );
    if (!confirm) return;
    bloc.add(SettingsImportEvent(path: path, json: json));
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.errorMessage != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            context.read<SettingsBloc>().add(const SettingsClearMessageEvent());
          } else if (state.infoMessage != null) {
            messenger.showSnackBar(SnackBar(content: Text(state.infoMessage!)));
            context.read<SettingsBloc>().add(const SettingsClearMessageEvent());
          }
        },
        builder: (context, state) {
          if (state.status == SettingsStatus.initial ||
              state.status == SettingsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SettingsStatus.error &&
              state.settings == const AppSettings()) {
            return _ErrorState(
              onRetry: () {
                context.read<SettingsBloc>().add(const SettingsLoadEvent());
              },
            );
          }
          return _buildContent(context, state, bloc);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SettingsState state,
    SettingsBloc bloc,
  ) {
    final settings = state.settings;
    return RefreshIndicator(
      onRefresh: () async {
        bloc.add(const SettingsLoadEvent());
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Financial Management
          SettingsSection(
            title: 'Financial',
            icon: Icons.account_balance_outlined,
            children: [
              SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budget',
                subtitle: 'Manage your budgets',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/app/budgets'),
              ),
              SettingsTile(
                icon: Icons.payments_outlined,
                title: 'Bills & Reminders',
                subtitle: 'Track bills and set payment reminders',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/app/bills'),
              ),
            ],
          ),

          // Appearance
          SettingsSection(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: ThemeSelector(
                  selectedMode: context.watch<ThemeBloc>().state.mode,
                  onChanged: (AppThemeMode mode) {
                    context.read<ThemeBloc>().add(ThemeChanged(mode));
                  },
                ),
              ),
            ],
          ),

          // Currency
          SettingsSection(
            title: 'Currency',
            icon: Icons.currency_exchange,
            children: [
              SettingsTile(
                icon: Icons.payments_outlined,
                title: 'Currency',
                subtitle: '${settings.currencySymbol} ${settings.currencyCode}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showCurrencyPicker(context, settings.currencyCode),
              ),
            ],
          ),

          // Notifications
          SettingsSection(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              NotificationToggle(
                title: 'Enable Notifications',
                subtitle: 'Master switch for all reminders',
                value: settings.notifications.notificationsEnabled,
                onChanged: (v) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    settings.notifications.copyWith(notificationsEnabled: v),
                  ),
                ),
              ),
              NotificationTimeTile(
                title: 'Morning Reminder',
                time: settings.notifications.morningReminderTime,
                onChanged: (time) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    settings.notifications.copyWith(morningReminderTime: time),
                  ),
                ),
              ),
              NotificationTimeTile(
                title: 'Evening Summary',
                time: settings.notifications.eveningSummaryTime,
                onChanged: (time) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    settings.notifications.copyWith(eveningSummaryTime: time),
                  ),
                ),
              ),
              NotificationToggle(
                title: 'Overspending Alerts',
                value: settings.notifications.overspendingAlertsEnabled,
                onChanged: (v) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    settings.notifications.copyWith(
                      overspendingAlertsEnabled: v,
                    ),
                  ),
                ),
              ),
              NotificationToggle(
                title: 'No-Expense Reminder',
                value: settings.notifications.noExpenseReminderEnabled,
                onChanged: (v) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    settings.notifications.copyWith(
                      noExpenseReminderEnabled: v,
                    ),
                  ),
                ),
              ),
              NotificationToggle(
                title: 'Quiet Hours',
                subtitle: 'Pause notifications at night',
                value: settings.notifications.quietHoursEnabled,
                onChanged: (v) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    settings.notifications.copyWith(quietHoursEnabled: v),
                  ),
                ),
              ),
            ],
          ),

          // Security
          SettingsSection(
            title: 'Security',
            icon: Icons.security_outlined,
            children: [
              BiometricTile(
                enabled: settings.biometricEnabled,
                isBusy: state.isBiometricBusy,
                message: state.biometricMessage,
                onChanged: (v) => bloc.add(SettingsUpdateBiometricEvent(v)),
              ),
            ],
          ),

          // Data Management
          SettingsSection(
            title: 'Data Management',
            icon: Icons.folder_open_outlined,
            children: [
              DataManagementCard(
                isBusy: state.isBusy,
                onExportCsv: () =>
                    bloc.add(const SettingsExportEvent(csv: true)),
                onExportJson: () =>
                    bloc.add(const SettingsExportEvent(csv: false)),
                onImportCsv: () => _pickAndImport(context, bloc, json: false),
                onImportJson: () => _pickAndImport(context, bloc, json: true),
                onBackup: () => bloc.add(const SettingsBackupEvent()),
                onRestore: () => _pickAndRestore(context, bloc),
              ),
            ],
          ),

          // Budget Management
          SettingsSection(
            title: 'Budget Management',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              SettingsTile(
                icon: Icons.replay,
                title: 'Reset Current Month',
                subtitle: 'Archive this month and start a new one',
                onTap: () async {
                  final confirm = await ResetConfirmationDialog.show(
                    context,
                    title: 'Reset Month?',
                    message:
                        'This will create a new month budget and roll '
                        'over your current period. Continue?',
                    confirmLabel: 'Reset',
                  );
                  if (confirm) bloc.add(const SettingsResetMonthEvent());
                },
              ),
              SettingsTile(
                icon: Icons.auto_fix_high,
                title: 'Reset Budget Amount',
                subtitle: 'Set a new budget for this month',
                onTap: () => _showBudgetAmountDialog(context, bloc),
              ),
            ],
          ),

          // App Updates
          BlocProvider<AppUpdateBloc>.value(
            value: di.getIt<AppUpdateBloc>(),
            child: const AppUpdateSection(),
          ),

          // About
          SettingsSection(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: const AboutCard(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _showBudgetAmountDialog(
    BuildContext context,
    SettingsBloc bloc,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Budget Amount'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly budget',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      bloc.add(SettingsResetBudgetEvent(result));
    }
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: AppSpacing.md),
          const Text('Could not load settings.'),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
