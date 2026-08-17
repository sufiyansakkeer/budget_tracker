import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/biometric_service.dart';
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

    SettingsBloc buildBloc() {
      return SettingsBloc(
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
        expect(bloc.state.biometricMessage, contains('isn\'t available'));
        expect(bloc.state.isBiometricBusy, false);

        await bloc.close();
      },
    );

    test(
      'enable with no enrolled biometric shows setup message and keeps OFF',
      () async {
        when(biometricService.getAvailability()).thenAnswer(
          (_) async => const BiometricAvailability(
            isDeviceSupported: true,
            canCheckBiometrics: true,
            availableTypes: [],
          ),
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
        expect(bloc.state.biometricMessage, contains('set up'));
        expect(bloc.state.isBiometricBusy, false);

        await bloc.close();
      },
    );

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
      expect(bloc.state.errorMessage, 'save failed');
      expect(bloc.state.isBiometricBusy, false);

      await bloc.close();
    });
  });
}
