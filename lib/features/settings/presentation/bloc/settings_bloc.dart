import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/settings_failure.dart';
import '../../domain/services/biometric_service.dart';
import '../../domain/usecases/backup_data_usecase.dart';
import '../../domain/usecases/export_data_usecase.dart';
import '../../domain/usecases/import_data_usecase.dart';
import '../../domain/usecases/load_settings_usecase.dart';
import '../../domain/usecases/reset_budget_usecase.dart';
import '../../domain/usecases/restore_data_usecase.dart';
import '../../domain/usecases/schedule_notifications_usecase.dart';
import '../../domain/usecases/update_biometric_usecase.dart';
import '../../domain/usecases/update_currency_usecase.dart';
import '../../domain/usecases/update_notification_settings_usecase.dart';
import 'settings_event.dart';
import 'settings_state.dart';

/// BLoC responsible for loading/saving app settings and managing data
/// operations (export, import, backup, restore, reset).
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final LoadSettingsUseCase loadSettingsUseCase;
  final UpdateCurrencyUseCase updateCurrencyUseCase;
  final UpdateNotificationSettingsUseCase updateNotificationSettingsUseCase;
  final UpdateBiometricUseCase updateBiometricUseCase;
  final BiometricService biometricService;
  final ExportDataUseCase exportDataUseCase;
  final ImportDataUseCase importDataUseCase;
  final BackupDataUseCase backupDataUseCase;
  final RestoreDataUseCase restoreDataUseCase;
  final ResetBudgetUseCase resetBudgetUseCase;
  final ScheduleNotificationsUseCase scheduleNotificationsUseCase;

  SettingsBloc({
    required this.loadSettingsUseCase,
    required this.updateCurrencyUseCase,
    required this.updateNotificationSettingsUseCase,
    required this.updateBiometricUseCase,
    required this.biometricService,
    required this.exportDataUseCase,
    required this.importDataUseCase,
    required this.backupDataUseCase,
    required this.restoreDataUseCase,
    required this.resetBudgetUseCase,
    required this.scheduleNotificationsUseCase,
  }) : super(const SettingsState()) {
    on<SettingsLoadEvent>(_onLoadSettings);
    on<SettingsUpdateCurrencyEvent>(_onUpdateCurrency);
    on<SettingsUpdateNotificationsEvent>(_onUpdateNotifications);
    on<SettingsUpdateBiometricEvent>(_onUpdateBiometric);
    on<SettingsExportEvent>(_onExport);
    on<SettingsImportEvent>(_onImport);
    on<SettingsBackupEvent>(_onBackup);
    on<SettingsRestoreEvent>(_onRestore);
    on<SettingsResetBudgetEvent>(_onResetBudget);
    on<SettingsResetMonthEvent>(_onResetMonth);
    on<SettingsClearMessageEvent>(_onClearMessage);
  }

  Future<void> _onLoadSettings(
    SettingsLoadEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SettingsStatus.loading,
        clearError: true,
        clearInfo: true,
      ),
    );
    final result = await loadSettingsUseCase();
    switch (result) {
      case SettingsSuccess(:final data):
        emit(
          state.copyWith(
            status: SettingsStatus.loaded,
            settings: data,
            clearError: true,
          ),
        );
        // Asynchronously check biometric availability so the Settings UI can
        // show a friendly "not available / not enrolled" message.
        await _checkBiometricAvailability(emit);
      case SettingsError(:final failure):
        emit(
          state.copyWith(
            status: SettingsStatus.error,
            errorMessage: failure.message,
          ),
        );
    }
  }

  /// Refreshes the friendly biometric availability message shown in the UI.
  Future<void> _checkBiometricAvailability(Emitter<SettingsState> emit) async {
    final availability = await biometricService.getAvailability();
    if (!availability.isDeviceSupported) {
      emit(
        state.copyWith(
          biometricMessage:
              'Biometric authentication isn\'t available on '
              'this device.',
        ),
      );
    } else if (!availability.hasBiometrics) {
      emit(
        state.copyWith(
          biometricMessage:
              'Please set up fingerprint or Face ID on your '
              'device first.',
        ),
      );
    } else {
      emit(state.copyWith(clearBiometricMessage: true));
    }
  }

  Future<void> _onUpdateCurrency(
    SettingsUpdateCurrencyEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    final result = await updateCurrencyUseCase(event.code, event.symbol);
    switch (result) {
      case SettingsSuccess():
        emit(
          state.copyWith(
            settings: state.settings.copyWith(
              currencyCode: event.code,
              currencySymbol: event.symbol,
            ),
            isBusy: false,
            clearError: true,
          ),
        );
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  Future<void> _onUpdateNotifications(
    SettingsUpdateNotificationsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));

    // Persist notification settings.
    final persistResult = await updateNotificationSettingsUseCase(
      event.settings,
    );
    if (persistResult case SettingsError(:final failure)) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    // Reschedule notifications.
    final updatedSettings = state.settings.copyWith(
      notifications: event.settings,
    );
    final scheduleResult = await scheduleNotificationsUseCase(updatedSettings);
    if (scheduleResult case SettingsError(:final failure)) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(
        settings: updatedSettings,
        isBusy: false,
        clearError: true,
        infoMessage: 'Notifications updated.',
      ),
    );
  }

  Future<void> _onUpdateBiometric(
    SettingsUpdateBiometricEvent event,
    Emitter<SettingsState> emit,
  ) async {
    // Prevent rapid/duplicate toggles while an authentication is in flight.
    if (state.isBiometricBusy) return;

    emit(state.copyWith(isBiometricBusy: true, clearBiometricMessage: true));

    // 1. Check device support / enrolled biometrics.
    final availability = await biometricService.getAvailability();
    if (!availability.isDeviceSupported) {
      emit(
        state.copyWith(
          isBiometricBusy: false,
          biometricMessage:
              'Biometric authentication isn\'t available on this device.',
        ),
      );
      return;
    }
    if (!availability.hasBiometrics) {
      emit(
        state.copyWith(
          isBiometricBusy: false,
          biometricMessage:
              'Please set up fingerprint or Face ID on your '
              'device first.',
        ),
      );
      return;
    }

    // 2. Authenticate before enabling OR disabling the security feature.
    debugPrint(
      '[Biometric] Toggle requested: ${event.enabled ? "enable" : "disable"}',
    );
    final authenticated = await biometricService.authenticate(
      reason: event.enabled
          ? 'Confirm to enable biometric lock'
          : 'Confirm to disable biometric lock',
    );
    if (!authenticated) {
      // Cancelled or failed — keep the toggle unchanged. Surface the failure
      // so the user knows authentication did not succeed.
      debugPrint('[Biometric] Authentication not successful; toggle unchanged');
      emit(
        state.copyWith(
          isBiometricBusy: false,
          biometricMessage: 'Authentication not completed. Toggle unchanged.',
        ),
      );
      return;
    }

    // 3. Persist the preference only after a successful authentication.
    final result = await updateBiometricUseCase(event.enabled);
    switch (result) {
      case SettingsSuccess():
        emit(
          state.copyWith(
            settings: state.settings.copyWith(biometricEnabled: event.enabled),
            isBiometricBusy: false,
            clearError: true,
          ),
        );
      case SettingsError(:final failure):
        emit(
          state.copyWith(isBiometricBusy: false, errorMessage: failure.message),
        );
    }
  }

  Future<void> _onExport(
    SettingsExportEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearInfo: true));
    final result = await exportDataUseCase(csv: event.csv);
    switch (result) {
      case SettingsSuccess(:final data):
        emit(state.copyWith(isBusy: false, infoMessage: data));
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  Future<void> _onImport(
    SettingsImportEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearInfo: true));
    final result = await importDataUseCase(event.path, json: event.json);
    switch (result) {
      case SettingsSuccess(:final data):
        emit(
          state.copyWith(isBusy: false, infoMessage: 'Imported $data items.'),
        );
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  Future<void> _onBackup(
    SettingsBackupEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearInfo: true));
    final result = await backupDataUseCase();
    switch (result) {
      case SettingsSuccess():
        emit(state.copyWith(isBusy: false, infoMessage: 'Backup created.'));
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  Future<void> _onRestore(
    SettingsRestoreEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearInfo: true));
    final result = await restoreDataUseCase(event.path);
    switch (result) {
      case SettingsSuccess(:final data):
        emit(state.copyWith(isBusy: false, infoMessage: data));
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  Future<void> _onResetBudget(
    SettingsResetBudgetEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearInfo: true));
    final result = await resetBudgetUseCase.resetBudgetAmount(event.amount);
    switch (result) {
      case SettingsSuccess():
        emit(
          state.copyWith(
            isBusy: false,
            infoMessage: 'Budget reset successfully.',
          ),
        );
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  Future<void> _onResetMonth(
    SettingsResetMonthEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearInfo: true));
    final result = await resetBudgetUseCase.resetCurrentMonth();
    switch (result) {
      case SettingsSuccess():
        emit(state.copyWith(isBusy: false, infoMessage: 'New month started.'));
      case SettingsError(:final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));
    }
  }

  void _onClearMessage(
    SettingsClearMessageEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearInfo: true));
  }
}
