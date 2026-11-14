import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';

import 'settings_bloc_test.mocks.dart';

void main() {
  provideDummy<SettingsResult<void>>(const SettingsSuccess(null));

  // UX-068: the change was saved, then scheduling failed and the bloc kept
  // the old settings, so the switch showed one value while storage held
  // another (and flipped on the next load).
  test('a saved change stays shown when scheduling fails', () async {
    final persist = MockUpdateNotificationSettingsUseCase();
    final schedule = MockScheduleNotificationsUseCase();
    const changed = NotificationSettings(morningReminderEnabled: false);
    when(
      persist.call(any),
    ).thenAnswer((_) async => const SettingsSuccess(null));
    when(schedule.call(any)).thenAnswer(
      (_) async => const SettingsError(
        SettingsFailure(
          type: SettingsErrorType.notificationPermissionDenied,
          message: 'Failed to schedule notifications: denied',
        ),
      ),
    );
    final bloc = SettingsBloc(
      loadSettingsUseCase: MockLoadSettingsUseCase(),
      updateCurrencyUseCase: MockUpdateCurrencyUseCase(),
      updateNotificationSettingsUseCase: persist,
      updateBiometricUseCase: MockUpdateBiometricUseCase(),
      biometricService: MockBiometricService(),
      exportDataUseCase: MockExportDataUseCase(),
      importDataUseCase: MockImportDataUseCase(),
      backupDataUseCase: MockBackupDataUseCase(),
      restoreDataUseCase: MockRestoreDataUseCase(),
      resetBudgetUseCase: MockResetBudgetUseCase(),
      scheduleNotificationsUseCase: schedule,
    );
    addTearDown(bloc.close);

    bloc.add(const SettingsUpdateNotificationsEvent(changed));
    await bloc.stream.firstWhere((s) => s.errorMessage != null);

    expect(bloc.state.settings.notifications, changed);
    expect(bloc.state.isBusy, isFalse);
    expect(bloc.state.infoMessage, isNull);
    expect(bloc.state.errorMessage, contains("couldn't be scheduled"));
    expect(
      bloc.state.settings,
      const AppSettings().copyWith(notifications: changed),
    );
  });
}
