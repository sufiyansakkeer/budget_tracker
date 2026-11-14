import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_state.dart';

import 'settings_bloc_test.mocks.dart';

/// UX-099: saving the currency or a reminder set the Data group's busy
/// state, which disabled Export, Import, Back up and Restore.
void main() {
  provideDummy<SettingsResult<void>>(const SettingsSuccess(null));

  late MockUpdateCurrencyUseCase currency;
  late MockUpdateNotificationSettingsUseCase persist;
  late MockScheduleNotificationsUseCase schedule;
  late SettingsBloc bloc;

  setUp(() {
    currency = MockUpdateCurrencyUseCase();
    persist = MockUpdateNotificationSettingsUseCase();
    schedule = MockScheduleNotificationsUseCase();
    when(
      persist.call(any),
    ).thenAnswer((_) async => const SettingsSuccess(null));
    when(
      schedule.call(any),
    ).thenAnswer((_) async => const SettingsSuccess(null));
    bloc = SettingsBloc(
      loadSettingsUseCase: MockLoadSettingsUseCase(),
      updateCurrencyUseCase: currency,
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
  });

  tearDown(() => bloc.close());

  Future<List<SettingsState>> statesOf(
    SettingsEvent event,
    bool Function(SettingsState) last,
  ) async {
    final states = <SettingsState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(event);
    await bloc.stream.firstWhere(last);
    await sub.cancel();
    return states;
  }

  test('a currency save never marks the Data group busy', () async {
    when(
      currency.call('OMR', 'ر.ع.'),
    ).thenAnswer((_) async => const SettingsSuccess(null));

    final states = await statesOf(
      const SettingsUpdateCurrencyEvent(code: 'OMR', symbol: 'ر.ع.'),
      (s) => s.settings.currencyCode == 'OMR',
    );

    expect(states.any((s) => s.isBusy), isFalse);
    expect(bloc.state.settings.currencyCode, 'OMR');
  });

  test('a failed currency save keeps the old one, still not busy', () async {
    when(currency.call(any, any)).thenAnswer(
      (_) async => const SettingsError(
        SettingsFailure(type: SettingsErrorType.saveFailure, message: 'disk'),
      ),
    );

    final states = await statesOf(
      const SettingsUpdateCurrencyEvent(code: 'OMR', symbol: 'ر.ع.'),
      (s) => s.errorMessage != null,
    );

    expect(states.any((s) => s.isBusy), isFalse);
    expect(bloc.state.settings.currencyCode, isNot('OMR'));
  });

  test('a reminder save never marks the Data group busy', () async {
    const changed = NotificationSettings(morningReminderEnabled: false);

    final states = await statesOf(
      const SettingsUpdateNotificationsEvent(changed),
      (s) => s.infoMessage != null,
    );

    expect(states.any((s) => s.isBusy), isFalse);
    expect(bloc.state.settings.notifications, changed);
  });
}
