import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/import_report.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/biometric_service.dart';
import 'package:monivo/features/settings/domain/services/file_delivery_service.dart';
import 'package:monivo/features/settings/domain/usecases/backup_data_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/export_data_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/import_data_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/reset_budget_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/restore_data_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/schedule_notifications_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/update_biometric_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/update_currency_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/update_notification_settings_usecase.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([
  LoadSettingsUseCase,
  UpdateCurrencyUseCase,
  UpdateNotificationSettingsUseCase,
  UpdateBiometricUseCase,
  BiometricService,
  ExportDataUseCase,
  ImportDataUseCase,
  BackupDataUseCase,
  RestoreDataUseCase,
  ResetBudgetUseCase,
  ScheduleNotificationsUseCase,
])
import 'settings_bloc_test.mocks.dart';

void main() {
  // Mockito needs dummy values for the sealed SettingsResult family so the
  // generated mocks can construct their default return values.
  provideDummy<SettingsResult<void>>(const SettingsSuccess(null));
  provideDummy<SettingsResult<AppSettings>>(
    const SettingsSuccess(AppSettings()),
  );

  group('SettingsBloc - Biometric Lock', () {
    late MockLoadSettingsUseCase loadSettingsUseCase;
    late MockUpdateBiometricUseCase updateBiometricUseCase;
    late MockBiometricService biometricService;

    SettingsBloc buildBloc({void Function(bool)? onLockPreferenceChanged}) {
      return SettingsBloc(
        onLockPreferenceChanged: onLockPreferenceChanged,
        loadSettingsUseCase: loadSettingsUseCase,
        updateCurrencyUseCase: MockUpdateCurrencyUseCase(),
        updateNotificationSettingsUseCase:
            MockUpdateNotificationSettingsUseCase(),
        updateBiometricUseCase: updateBiometricUseCase,
        biometricService: biometricService,
        exportDataUseCase: MockExportDataUseCase(),
        importDataUseCase: MockImportDataUseCase(),
        backupDataUseCase: MockBackupDataUseCase(),
        restoreDataUseCase: MockRestoreDataUseCase(),
        resetBudgetUseCase: MockResetBudgetUseCase(),
        scheduleNotificationsUseCase: MockScheduleNotificationsUseCase(),
      );
    }

    setUp(() {
      loadSettingsUseCase = MockLoadSettingsUseCase();
      updateBiometricUseCase = MockUpdateBiometricUseCase();
      biometricService = MockBiometricService();

      // Default: device supports biometrics and has one enrolled type.
      when(biometricService.getAvailability()).thenAnswer(
        (_) async => const BiometricAvailability(
          isDeviceSupported: true,
          canCheckBiometrics: true,
          availableTypes: [BiometricType.face],
        ),
      );
      when(
        biometricService.authenticate(
          reason: anyNamed('reason'),
          useErrorDialogs: anyNamed('useErrorDialogs'),
        ),
      ).thenAnswer((_) async => true);
    });

    test('enable: authenticates, persists true, emits enabled state', () async {
      when(
        updateBiometricUseCase.call(true),
      ).thenAnswer((_) async => const SettingsSuccess(null));

      final bloc = buildBloc();
      bloc.add(const SettingsUpdateBiometricEvent(true));
      await Future<void>.delayed(Duration.zero);

      verify(
        biometricService.authenticate(
          reason: 'Confirm to enable biometric lock',
          useErrorDialogs: anyNamed('useErrorDialogs'),
        ),
      ).called(1);
      verify(updateBiometricUseCase.call(true)).called(1);
      expect(bloc.state.settings.biometricEnabled, true);
      expect(bloc.state.isBiometricBusy, false);

      await bloc.close();
    });

    test(
      'enable with cancelled auth keeps toggle OFF and does not persist',
      () async {
        when(
          biometricService.authenticate(
            reason: anyNamed('reason'),
            useErrorDialogs: anyNamed('useErrorDialogs'),
          ),
        ).thenAnswer((_) async => false);

        final bloc = buildBloc();
        bloc.add(const SettingsUpdateBiometricEvent(true));
        await Future<void>.delayed(Duration.zero);

        verify(
          biometricService.authenticate(
            reason: anyNamed('reason'),
            useErrorDialogs: anyNamed('useErrorDialogs'),
          ),
        ).called(1);
        verifyNever(updateBiometricUseCase.call(true));
        expect(bloc.state.settings.biometricEnabled, false);
        expect(bloc.state.isBiometricBusy, false);

        await bloc.close();
      },
    );

    test(
      'enable on unsupported device shows message and keeps toggle OFF',
      () async {
        when(biometricService.getAvailability()).thenAnswer(
          (_) async => const BiometricAvailability(isDeviceSupported: false),
        );

        final bloc = buildBloc();
        bloc.add(const SettingsUpdateBiometricEvent(true));
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          biometricService.authenticate(
            reason: anyNamed('reason'),
            useErrorDialogs: anyNamed('useErrorDialogs'),
          ),
        );
        verifyNever(updateBiometricUseCase.call(true));
        expect(bloc.state.settings.biometricEnabled, false);
        expect(bloc.state.biometricMessage, contains('screen lock'));
        expect(bloc.state.isBiometricBusy, false);

        await bloc.close();
      },
    );

    test(
      'UX-012: a screen lock without biometrics can enable the lock (the '
      'prompt accepts the PIN), and the lock bloc is told at once (UX-011)',
      () async {
        when(biometricService.getAvailability()).thenAnswer(
          (_) async => const BiometricAvailability(
            isDeviceSupported: true,
            canCheckBiometrics: true,
            availableTypes: [],
          ),
        );
        when(
          updateBiometricUseCase.call(true),
        ).thenAnswer((_) async => const SettingsSuccess(null));
        final told = <bool>[];

        final bloc = buildBloc(onLockPreferenceChanged: told.add);
        bloc.add(const SettingsUpdateBiometricEvent(true));
        await Future<void>.delayed(Duration.zero);

        verify(updateBiometricUseCase.call(true)).called(1);
        expect(bloc.state.settings.biometricEnabled, true);
        expect(told, [true]);

        await bloc.close();
      },
    );

    test('UX-011: a failed save never tells the lock bloc', () async {
      when(updateBiometricUseCase.call(true)).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(type: SettingsErrorType.saveFailure, message: 'x'),
        ),
      );
      final told = <bool>[];

      final bloc = buildBloc(onLockPreferenceChanged: told.add);
      bloc.add(const SettingsUpdateBiometricEvent(true));
      await Future<void>.delayed(Duration.zero);

      expect(told, isEmpty);
      await bloc.close();
    });

    test(
      'disable: authenticates, persists false, emits disabled state',
      () async {
        when(loadSettingsUseCase()).thenAnswer(
          (_) async =>
              const SettingsSuccess(AppSettings(biometricEnabled: true)),
        );
        when(
          updateBiometricUseCase.call(false),
        ).thenAnswer((_) async => const SettingsSuccess(null));

        final bloc = buildBloc();
        bloc.add(const SettingsLoadEvent());
        bloc.add(const SettingsUpdateBiometricEvent(false));
        await Future<void>.delayed(Duration.zero);

        verify(
          biometricService.authenticate(
            reason: 'Confirm to disable biometric lock',
            useErrorDialogs: anyNamed('useErrorDialogs'),
          ),
        ).called(1);
        verify(updateBiometricUseCase.call(false)).called(1);
        expect(bloc.state.settings.biometricEnabled, false);
        expect(bloc.state.isBiometricBusy, false);

        await bloc.close();
      },
    );

    test('disable with cancelled auth keeps toggle ON', () async {
      when(loadSettingsUseCase()).thenAnswer(
        (_) async => const SettingsSuccess(AppSettings(biometricEnabled: true)),
      );
      when(
        biometricService.authenticate(
          reason: anyNamed('reason'),
          useErrorDialogs: anyNamed('useErrorDialogs'),
        ),
      ).thenAnswer((_) async => false);

      final bloc = buildBloc();
      bloc.add(const SettingsLoadEvent());
      bloc.add(const SettingsUpdateBiometricEvent(false));
      await Future<void>.delayed(Duration.zero);

      verifyNever(updateBiometricUseCase.call(false));
      expect(bloc.state.settings.biometricEnabled, true);
      expect(bloc.state.isBiometricBusy, false);

      await bloc.close();
    });

    test('persistence: load emits enabled state when saved true', () async {
      when(loadSettingsUseCase()).thenAnswer(
        (_) async => const SettingsSuccess(AppSettings(biometricEnabled: true)),
      );

      final bloc = buildBloc();
      bloc.add(const SettingsLoadEvent());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.settings.biometricEnabled, true);
      expect(bloc.state.status == SettingsStatus.loaded, true);

      await bloc.close();
    });

    test('save failure surfaces friendly error and keeps toggle OFF', () async {
      when(updateBiometricUseCase.call(true)).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(
            type: SettingsErrorType.saveFailure,
            message: 'save failed',
          ),
        ),
      );

      final bloc = buildBloc();
      bloc.add(const SettingsUpdateBiometricEvent(true));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.settings.biometricEnabled, false);
      // The raw failure text stays out of sight; the message says what
      // didn't happen.
      expect(
        bloc.state.errorMessage,
        "Couldn't save the app lock setting. Try again.",
      );
      expect(bloc.state.isBiometricBusy, false);

      await bloc.close();
    });
  });

  group('SettingsBloc - Restore', () {
    late MockRestoreDataUseCase restoreDataUseCase;

    setUp(() {
      provideDummy<SettingsResult<String>>(const SettingsSuccess(''));
      restoreDataUseCase = MockRestoreDataUseCase();
    });

    SettingsBloc buildBloc() {
      return SettingsBloc(
        loadSettingsUseCase: MockLoadSettingsUseCase(),
        updateCurrencyUseCase: MockUpdateCurrencyUseCase(),
        updateNotificationSettingsUseCase:
            MockUpdateNotificationSettingsUseCase(),
        updateBiometricUseCase: MockUpdateBiometricUseCase(),
        biometricService: MockBiometricService(),
        exportDataUseCase: MockExportDataUseCase(),
        importDataUseCase: MockImportDataUseCase(),
        backupDataUseCase: MockBackupDataUseCase(),
        restoreDataUseCase: restoreDataUseCase,
        resetBudgetUseCase: MockResetBudgetUseCase(),
        scheduleNotificationsUseCase: MockScheduleNotificationsUseCase(),
      );
    }

    /// Counts notifications on every bus a mounted tab listens to.
    Map<String, int> listenToBuses() {
      final counts = <String, int>{};
      for (final bus in [
        RefreshBuses.budgets,
        RefreshBuses.expenses,
        RefreshBuses.bills,
      ]) {
        counts[bus.name] = 0;
        final sub = bus.changes.listen(
          (_) => counts[bus.name] = counts[bus.name]! + 1,
        );
        addTearDown(sub.cancel);
      }
      return counts;
    }

    test('a successful restore tells every tab to re-read', () async {
      when(
        restoreDataUseCase.call('/backup.json'),
      ).thenAnswer((_) async => const SettingsSuccess('Restored.'));
      final counts = listenToBuses();

      final bloc = buildBloc();
      bloc.add(const SettingsRestoreEvent('/backup.json'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.infoMessage, 'Backup restored.');
      expect(counts, {'budgets': 1, 'expenses': 1, 'bills': 1});
      await bloc.close();
    });

    test('a failed restore notifies nothing', () async {
      when(restoreDataUseCase.call('/backup.json')).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(
            type: SettingsErrorType.restoreFailure,
            message: 'Bad',
          ),
        ),
      );
      final counts = listenToBuses();

      final bloc = buildBloc();
      bloc.add(const SettingsRestoreEvent('/backup.json'));
      await Future<void>.delayed(Duration.zero);

      expect(
        bloc.state.errorMessage,
        "Couldn't restore the backup. Try again.",
      );
      expect(counts, {'budgets': 0, 'expenses': 0, 'bills': 0});
      await bloc.close();
    });
  });
  group('SettingsBloc - Import and change amount (review: no buses fired)', () {
    late MockImportDataUseCase importDataUseCase;
    late MockResetBudgetUseCase resetBudgetUseCase;
    late MockBackupDataUseCase backupDataUseCase;
    late MockRestoreDataUseCase restoreDataUseCase;

    setUp(() {
      provideDummy<SettingsResult<String>>(const SettingsSuccess(''));
      provideDummy<SettingsResult<int>>(const SettingsSuccess(0));
      provideDummy<SettingsResult<ImportReport>>(
        const SettingsSuccess(ImportReport()),
      );
      provideDummy<SettingsResult<FileDeliveryOutcome>>(
        const SettingsSuccess(FileDeliveryOutcome.cancelled),
      );
      importDataUseCase = MockImportDataUseCase();
      resetBudgetUseCase = MockResetBudgetUseCase();
      backupDataUseCase = MockBackupDataUseCase();
      restoreDataUseCase = MockRestoreDataUseCase();
    });

    SettingsBloc buildBloc() {
      return SettingsBloc(
        loadSettingsUseCase: MockLoadSettingsUseCase(),
        updateCurrencyUseCase: MockUpdateCurrencyUseCase(),
        updateNotificationSettingsUseCase:
            MockUpdateNotificationSettingsUseCase(),
        updateBiometricUseCase: MockUpdateBiometricUseCase(),
        biometricService: MockBiometricService(),
        exportDataUseCase: MockExportDataUseCase(),
        importDataUseCase: importDataUseCase,
        backupDataUseCase: backupDataUseCase,
        restoreDataUseCase: restoreDataUseCase,
        resetBudgetUseCase: resetBudgetUseCase,
        scheduleNotificationsUseCase: MockScheduleNotificationsUseCase(),
      );
    }

    Map<String, int> listenToBuses() {
      final counts = <String, int>{};
      for (final bus in [
        RefreshBuses.budgets,
        RefreshBuses.expenses,
        RefreshBuses.bills,
      ]) {
        counts[bus.name] = 0;
        final sub = bus.changes.listen(
          (_) => counts[bus.name] = counts[bus.name]! + 1,
        );
        addTearDown(sub.cancel);
      }
      return counts;
    }

    test('changing the budget amount tells budget listeners', () async {
      when(
        resetBudgetUseCase.resetBudgetAmount(20000),
      ).thenAnswer((_) async => const SettingsSuccess('b1'));
      final counts = listenToBuses();

      final bloc = buildBloc();
      bloc.add(const SettingsResetBudgetEvent(20000));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.infoMessage, 'Budget amount updated.');
      expect(counts, {'budgets': 1, 'expenses': 0, 'bills': 0});
      await bloc.close();
    });

    test('a rejected amount notifies nothing', () async {
      when(resetBudgetUseCase.resetBudgetAmount(0)).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(
            type: SettingsErrorType.invalidData,
            message: 'Budget amount must be greater than zero.',
          ),
        ),
      );
      final counts = listenToBuses();

      final bloc = buildBloc();
      bloc.add(const SettingsResetBudgetEvent(0));
      await Future<void>.delayed(Duration.zero);

      expect(counts, {'budgets': 0, 'expenses': 0, 'bills': 0});
      await bloc.close();
    });

    test('a successful import tells every tab to re-read', () async {
      when(importDataUseCase.call('/data.json', json: true)).thenAnswer(
        (_) async => const SettingsSuccess(ImportReport(imported: 12)),
      );
      final counts = listenToBuses();

      final bloc = buildBloc();
      bloc.add(const SettingsImportEvent(path: '/data.json', json: true));
      await Future<void>.delayed(Duration.zero);

      // A JSON import now counts what it added, like a CSV one.
      expect(bloc.state.infoMessage, 'Imported 12 expenses.');
      expect(counts, {'budgets': 1, 'expenses': 1, 'bills': 1});
      await bloc.close();
    });

    test('a CSV import says how many expenses it added', () async {
      when(importDataUseCase.call('/data.csv', json: false)).thenAnswer(
        (_) async => const SettingsSuccess(ImportReport(imported: 12)),
      );

      final bloc = buildBloc();
      bloc.add(const SettingsImportEvent(path: '/data.csv'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.infoMessage, 'Imported 12 expenses.');
      await bloc.close();
    });

    group('UX-008: the import message counts what was skipped', () {
      test('a re-import that adds nothing says so, not success', () {
        expect(
          SettingsBloc.importMessage(const ImportReport(duplicates: 22)),
          'Nothing new to import. Skipped 22 rows: 22 already on this '
          'device.',
        );
      });

      test('added and skipped rows, each reason named', () {
        expect(
          SettingsBloc.importMessage(
            const ImportReport(
              imported: 3,
              duplicates: 2,
              unreadable: 1,
              otherCurrency: 1,
            ),
          ),
          "Imported 3 expenses. Skipped 4 rows: 2 already on this device, 1 "
          "couldn't be read and 1 in a currency none of your budgets use.",
        );
      });

      test('a data file that updated records says so', () {
        expect(
          SettingsBloc.importMessage(
            const ImportReport(imported: 1, updated: 4),
          ),
          'Imported 1 new expense and updated 4.',
        );
        expect(
          SettingsBloc.importMessage(const ImportReport(updated: 4)),
          'Updated 4 expenses. Nothing new to add.',
        );
      });
    });

    group('UX-002: a backup is reported only once it reached the user', () {
      for (final (outcome, message) in [
        (
          FileDeliveryOutcome.saved,
          'Backup saved. Restore can open it from where you saved it.',
        ),
        (FileDeliveryOutcome.shared, 'Backup shared.'),
        (
          FileDeliveryOutcome.cancelled,
          'Backup not saved. Nothing was kept on this device.',
        ),
      ]) {
        test('$outcome', () async {
          when(
            backupDataUseCase.call(destination: FileDestination.device),
          ).thenAnswer((_) async => SettingsSuccess(outcome));

          final bloc = buildBloc();
          bloc.add(const SettingsBackupEvent(FileDestination.device));
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.infoMessage, message);
          expect(bloc.state.isBusy, isFalse);
          await bloc.close();
        });
      }
    });

    test('UX-003: an export picked for Restore says to use Import', () async {
      when(restoreDataUseCase.call('/export.json')).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(
            type: SettingsErrorType.wrongFileKind,
            message: 'This is a Monivo export, not a backup.',
          ),
        ),
      );

      final bloc = buildBloc();
      bloc.add(const SettingsRestoreEvent('/export.json'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.errorMessage, 'This is a Monivo export, not a backup.');
      await bloc.close();
    });

    test('an unreadable file explains what can be imported', () async {
      when(importDataUseCase.call('/data.json', json: true)).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(
            type: SettingsErrorType.invalidData,
            message: 'Corrupted JSON file: FormatException: Unexpected end',
          ),
        ),
      );

      final bloc = buildBloc();
      bloc.add(const SettingsImportEvent(path: '/data.json', json: true));
      await Future<void>.delayed(Duration.zero);

      expect(
        bloc.state.errorMessage,
        startsWith("This file couldn't be imported."),
      );
      expect(bloc.state.errorMessage, isNot(contains('FormatException')));
      await bloc.close();
    });

    test('a failed import notifies nothing', () async {
      when(importDataUseCase.call('/data.json', json: true)).thenAnswer(
        (_) async => const SettingsError(
          SettingsFailure(
            type: SettingsErrorType.importFailure,
            message: 'Bad',
          ),
        ),
      );
      final counts = listenToBuses();

      final bloc = buildBloc();
      bloc.add(const SettingsImportEvent(path: '/data.json', json: true));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.errorMessage, "Couldn't import the file. Try again.");
      expect(counts, {'budgets': 0, 'expenses': 0, 'bills': 0});
      await bloc.close();
    });
  });
}
