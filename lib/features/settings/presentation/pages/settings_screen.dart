import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/di/injection.dart' as di;
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../app_update/presentation/bloc/app_update_bloc.dart';
import '../../../app_update/presentation/widgets/app_update_section.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/color_palette_entity.dart';
import '../../domain/entities/currency_entity.dart';
import '../../domain/entities/theme_mode_entity.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';
import '../widgets/about_section.dart';
import '../widgets/biometric_tile.dart';
import '../widgets/currency_selector.dart';
import '../widgets/data_format_sheet.dart';
import '../widgets/integrity_result_sheet.dart';
import '../widgets/notification_time_tile.dart';
import '../widgets/notification_toggle.dart';
import '../widgets/reset_confirmation_dialog.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_summary.dart';
import '../widgets/settings_tile.dart';
import '../widgets/theme_selector.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/navigation/push_unique.dart';

/// Settings, grouped by what the user is trying to change.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Set once a load has completed so reloads keep the list on screen.
  bool _loadedOnce = false;

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
    final bloc = context.read<SettingsBloc>();
    AppBottomSheet.show<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(
            title: 'Currency',
            subtitle: 'Default for new budgets and app-wide amounts.',
          ),
          CurrencySelector(
            selectedCode: selectedCode,
            onSelected: (CurrencyEntity currency) {
              bloc.add(
                SettingsUpdateCurrencyEvent(
                  code: currency.code,
                  symbol: currency.symbol,
                ),
              );
              // Update currency provider for immediate UI change.
              di.getIt<CurrencyProvider>().updateCurrency(
                currency.code,
                currency.symbol,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _pickAndRestore(BuildContext context, SettingsBloc bloc) async {
    final path = await _pickFile(json: true);
    if (path == null || !context.mounted) return;
    final confirm = await ResetConfirmationDialog.show(
      context,
      title: 'Restore this backup?',
      message:
          'Your current budgets, expenses, bills and settings will be '
          'replaced with the backup. This cannot be undone.',
      confirmLabel: 'Restore',
      icon: Icons.settings_backup_restore_rounded,
      isDestructive: true,
    );
    if (confirm) bloc.add(SettingsRestoreEvent(path));
  }

  Future<void> _pickAndImport(
    BuildContext context,
    SettingsBloc bloc, {
    required bool json,
  }) async {
    final path = await _pickFile(json: json);
    if (path == null || !context.mounted) return;
    final confirm = await ResetConfirmationDialog.show(
      context,
      title: 'Import this file?',
      message:
          'Records from the ${json ? 'JSON' : 'CSV'} file will be merged '
          'into your existing data.',
      confirmLabel: 'Import',
      icon: Icons.download_rounded,
      isDestructive: false,
    );
    if (confirm) bloc.add(SettingsImportEvent(path: path, json: json));
  }

  Future<void> _startNewPeriod(BuildContext context, SettingsBloc bloc) async {
    final confirm = await ResetConfirmationDialog.show(
      context,
      title: 'Start a new budget period?',
      message:
          'The active budget is archived (its expenses are kept) and a new '
          '31-day budget with the same amount and currency starts today. '
          'Unpaid bills paid from it, and its kept-aside and savings '
          'amounts, move to the new budget.',
      confirmLabel: 'Start',
      icon: Icons.replay_rounded,
      isDestructive: false,
    );
    if (confirm) bloc.add(const SettingsResetMonthEvent());
  }

  Future<void> _showBudgetAmountDialog(
    BuildContext context,
    SettingsBloc bloc,
  ) async {
    final controller = TextEditingController();
    try {
      final result = await AppDialog.show<double>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change budget amount'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'New total for the active budget',
              prefixText: '${bloc.state.settings.currencySymbol} ',
            ),
            onSubmitted: (v) =>
                Navigator.of(dialogContext).pop(double.tryParse(v)),
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
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        // Showing a snackbar immediately clears the message, so every toast
        // emitted twice and rebuilt this ~20-tile list both times.
        buildWhen: (prev, curr) =>
            prev.settings != curr.settings ||
            prev.status != curr.status ||
            prev.isBusy != curr.isBusy ||
            prev.isBiometricBusy != curr.isBiometricBusy ||
            prev.biometricMessage != curr.biometricMessage,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.integrityResult != null) {
            final result = state.integrityResult!;
            bloc.add(const SettingsClearMessageEvent());
            IntegrityResultSheet.show(context, result);
            return;
          }
          if (state.errorMessage != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            bloc.add(const SettingsClearMessageEvent());
          } else if (state.infoMessage != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.infoMessage!)));
            bloc.add(const SettingsClearMessageEvent());
          }
        },
        builder: (context, state) {
          // Default settings are a valid loaded result, so "never loaded"
          // must come from the status, not from comparing values: otherwise
          // every reload on a fresh install swaps the list for a skeleton.
          if (state.status == SettingsStatus.loaded) _loadedOnce = true;
          final neverLoaded = !_loadedOnce;
          final Widget child;
          if ((state.status == SettingsStatus.initial ||
                  state.status == SettingsStatus.loading) &&
              neverLoaded) {
            child = const FormSkeleton(key: ValueKey('loading'), rows: 6);
          } else if (state.status == SettingsStatus.error && neverLoaded) {
            child = ErrorState(
              key: const ValueKey('error'),
              title: "Couldn't load settings",
              message: 'Please try again.',
              onRetry: () => bloc.add(const SettingsLoadEvent()),
            );
          } else {
            child = _buildContent(context, state, bloc);
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }

  String _formatTime(BuildContext context, NotificationTime time) {
    return TimeOfDay(hour: time.hour, minute: time.minute).format(context);
  }

  Future<void> _export(BuildContext context, SettingsBloc bloc) async {
    final format = await DataFormatSheet.showExport(context);
    if (format == null) return;
    bloc.add(SettingsExportEvent(csv: format == DataFormat.csv));
  }

  Future<void> _import(BuildContext context, SettingsBloc bloc) async {
    final format = await DataFormatSheet.showImport(context);
    if (format == null || !context.mounted) return;
    await _pickAndImport(context, bloc, json: format == DataFormat.json);
  }

  Widget _buildContent(
    BuildContext context,
    SettingsState state,
    SettingsBloc bloc,
  ) {
    final settings = state.settings;
    final notifications = settings.notifications;
    final themeState = context.watch<ThemeBloc>().state;
    final themeLabel = themeOptions
        .firstWhere(
          (o) => o.mode == themeState.mode,
          orElse: () => themeOptions.first,
        )
        .label;
    final paletteLabel = paletteOptions
        .firstWhere(
          (o) => o.palette == themeState.palette,
          orElse: () => paletteOptions.first,
        )
        .label;
    final morning = _formatTime(context, notifications.morningReminderTime);
    final evening = _formatTime(context, notifications.eveningSummaryTime);
    final dataEnabled = !state.isBusy;

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: () {
        bloc.add(const SettingsLoadEvent());
        return bloc.stream
            .firstWhere((s) => s.status != SettingsStatus.loading)
            .timeout(const Duration(seconds: 8), onTimeout: () => bloc.state);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: [
          SettingsSummary(
            key: const Key('settingsSummary'),
            currency: settings.currencyCode,
            theme: '$themeLabel · $paletteLabel',
            reminders: notifications.notificationsEnabled
                ? '$morning · $evening'
                : 'Off',
            lock: settings.biometricEnabled ? 'On' : 'Off',
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsSection(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
                child: ThemeSelector(
                  selectedMode: themeState.mode,
                  onChanged: (AppThemeMode mode) =>
                      context.read<ThemeBloc>().add(ThemeChanged(mode)),
                ),
              ),
              SettingsTile(
                leading: _PaletteSwatch(palette: themeState.palette),
                title: 'Color palette',
                value: paletteLabel,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushUnique(AppRouter.palettePath),
              ),
            ],
          ),

          SettingsSection(
            title: 'Budgets & bills',
            children: [
              SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budgets',
                subtitle: 'Create, switch, edit and archive budgets',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushUnique('/app/budgets'),
              ),
              SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'Bills',
                subtitle:
                    'Due dates, recurring bills and reminders. Reminders '
                    'are set on each bill.',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushUnique('/app/bills'),
              ),
              SettingsTile(
                icon: Icons.payments_outlined,
                title: 'Currency',
                subtitle: 'Default for new budgets',
                value: '${settings.currencySymbol} ${settings.currencyCode}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showCurrencyPicker(context, settings.currencyCode),
              ),
              SettingsTile(
                icon: Icons.replay_rounded,
                title: 'Start new budget period',
                subtitle:
                    'Archive the active budget and start a fresh 31-day one '
                    'with the same amount',
                onTap: () => _startNewPeriod(context, bloc),
              ),
              SettingsTile(
                icon: Icons.tune_rounded,
                title: 'Change active budget amount',
                subtitle: 'Dates and expenses stay as they are',
                onTap: () => _showBudgetAmountDialog(context, bloc),
              ),
            ],
          ),

          SettingsSection(
            title: 'Expenses & tools',
            children: [
              SettingsTile(
                key: const Key('settingsCategoriesTile'),
                icon: Icons.category_outlined,
                title: 'Categories',
                subtitle: 'Add your own, rename, restyle or archive',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushUnique('/app/categories'),
              ),
              SettingsTile(
                key: const Key('settingsCurrencyConverterTile'),
                icon: Icons.currency_exchange_rounded,
                title: 'Currency converter',
                subtitle:
                    'Daily reference rates. Works offline with saved rates.',
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.pushUnique(AppRouter.currencyConverterPath),
              ),
            ],
          ),

          SettingsSection(
            title: 'Notifications',
            description:
                'Notification permission must be allowed in your device '
                'settings.',
            children: [
              NotificationToggle(
                title: 'Daily notifications',
                subtitle: 'Morning safe-spending reminder and evening summary',
                value: notifications.notificationsEnabled,
                onChanged: (v) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    notifications.copyWith(notificationsEnabled: v),
                  ),
                ),
              ),
              NotificationTimeTile(
                title: 'Morning reminder',
                subtitle: "Today's Safe Spending for each budget running today",
                icon: Icons.wb_sunny_outlined,
                enabled: notifications.notificationsEnabled,
                time: notifications.morningReminderTime,
                onChanged: (time) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    notifications.copyWith(morningReminderTime: time),
                  ),
                ),
              ),
              NotificationTimeTile(
                title: 'Evening summary',
                subtitle: 'A nudge to review the day',
                icon: Icons.nights_stay_outlined,
                enabled: notifications.notificationsEnabled,
                time: notifications.eveningSummaryTime,
                onChanged: (time) => bloc.add(
                  SettingsUpdateNotificationsEvent(
                    notifications.copyWith(eveningSummaryTime: time),
                  ),
                ),
              ),
            ],
          ),

          SettingsSection(
            title: 'Security',
            children: [
              BiometricTile(
                enabled: settings.biometricEnabled,
                isBusy: state.isBiometricBusy,
                message: state.biometricMessage,
                onChanged: (v) => bloc.add(SettingsUpdateBiometricEvent(v)),
              ),
            ],
          ),

          SettingsSection(
            title: 'Data',
            busy: state.isBusy,
            children: [
              SettingsTile(
                key: const Key('settingsExportTile'),
                icon: Icons.ios_share_rounded,
                title: 'Export',
                subtitle: 'Your expenses as a spreadsheet or a data file',
                trailing: const Icon(Icons.chevron_right),
                enabled: dataEnabled,
                onTap: () => _export(context, bloc),
              ),
              SettingsTile(
                key: const Key('settingsImportTile'),
                icon: Icons.download_rounded,
                title: 'Import',
                subtitle: 'Merge expenses from a spreadsheet or a data file',
                trailing: const Icon(Icons.chevron_right),
                enabled: dataEnabled,
                onTap: () => _import(context, bloc),
              ),
              SettingsTile(
                key: const Key('settingsBackupTile'),
                icon: Icons.backup_outlined,
                title: 'Back up',
                subtitle:
                    'One file with all your budgets, expenses, bills and '
                    'settings',
                enabled: dataEnabled,
                onTap: () => bloc.add(const SettingsBackupEvent()),
              ),
              SettingsTile(
                key: const Key('settingsRestoreTile'),
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore from backup',
                subtitle: 'Replaces everything on this device with a backup',
                destructive: true,
                enabled: dataEnabled,
                onTap: () => _pickAndRestore(context, bloc),
              ),
              if (bloc.integrityService != null)
                SettingsTile(
                  key: const Key('checkIntegrityButton'),
                  icon: Icons.health_and_safety_outlined,
                  title: 'Check database health',
                  subtitle:
                      'Looks for expenses, bills or budgets that no longer '
                      'link up correctly',
                  enabled: dataEnabled,
                  onTap: () => bloc.add(const SettingsCheckIntegrityEvent()),
                ),
            ],
          ),

          BlocProvider<AppUpdateBloc>.value(
            value: di.getIt<AppUpdateBloc>(),
            child: const AppUpdateSection(),
          ),

          const AboutSection(),
        ],
      ),
    );
  }
}

/// The palette's primary, secondary and tertiary colours as three
/// overlapping dots, at the size of a row's icon tile.
class _PaletteSwatch extends StatelessWidget {
  final ColorPalette palette;

  const _PaletteSwatch({required this.palette});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppColorTokens.fromPalette(palette, theme.brightness);
    const dot = 20.0;
    const step = (AppSizes.avatarSm - dot) / 2;
    return SizedBox(
      width: AppSizes.avatarSm,
      height: AppSizes.avatarSm,
      child: Stack(
        children: [
          for (final (i, color) in [
            tokens.primary,
            tokens.secondary,
            tokens.tertiary,
          ].indexed)
            PositionedDirectional(
              start: i * step,
              top: step,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surfaceContainerLow,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
