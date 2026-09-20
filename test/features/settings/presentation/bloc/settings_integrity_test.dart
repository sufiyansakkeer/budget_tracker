import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/services/database_integrity_service.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/settings_event.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/in_memory_database.dart';
import 'settings_bloc_test.mocks.dart';

/// Always reports a problem, without needing a corrupted database.
class FailingIntegrityService extends DatabaseIntegrityService {
  FailingIntegrityService({required super.database});

  @override
  Future<IntegrityCheckResult> runFullCheck() async {
    throw Exception('disk error');
  }
}

void main() {
  late AppDatabase database;

  setUpAll(() {
    provideDummy<SettingsResult<AppSettings>>(
      const SettingsSuccess(AppSettings()),
    );
  });

  SettingsBloc build({DatabaseIntegrityService? integrityService}) {
    final loadSettings = MockLoadSettingsUseCase();
    when(
      loadSettings(),
    ).thenAnswer((_) async => const SettingsSuccess(AppSettings()));
    return SettingsBloc(
      loadSettingsUseCase: loadSettings,
      updateCurrencyUseCase: MockUpdateCurrencyUseCase(),
      updateNotificationSettingsUseCase:
          MockUpdateNotificationSettingsUseCase(),
      updateBiometricUseCase: MockUpdateBiometricUseCase(),
      biometricService: MockBiometricService(),
      exportDataUseCase: MockExportDataUseCase(),
      importDataUseCase: MockImportDataUseCase(),
      backupDataUseCase: MockBackupDataUseCase(),
      restoreDataUseCase: MockRestoreDataUseCase(),
      resetBudgetUseCase: MockResetBudgetUseCase(),
      scheduleNotificationsUseCase: MockScheduleNotificationsUseCase(),
      integrityService: integrityService,
    );
  }

  setUp(() async {
    database = await createInMemoryDatabase();
  });

  tearDown(() => database.close());

  test('a clean database passes the check', () async {
    final bloc = build(
      integrityService: DatabaseIntegrityService(database: database),
    );
    addTearDown(bloc.close);

    bloc.add(const SettingsCheckIntegrityEvent());
    final state = await bloc.stream.firstWhere(
      (s) => s.integrityResult != null,
    );

    expect(state.isBusy, isFalse);
    expect(state.integrityResult!.passed, isTrue);
    expect(state.integrityResult!.issues, isEmpty);
  });

  test('clearing messages also clears the result so it shows once', () async {
    final bloc = build(
      integrityService: DatabaseIntegrityService(database: database),
    );
    addTearDown(bloc.close);

    bloc.add(const SettingsCheckIntegrityEvent());
    await bloc.stream.firstWhere((s) => s.integrityResult != null);
    bloc.add(const SettingsClearMessageEvent());
    final cleared = await bloc.stream.firstWhere(
      (s) => s.integrityResult == null,
    );

    expect(cleared.integrityResult, isNull);
  });

  test('a failure is reported without a result', () async {
    final bloc = build(
      integrityService: FailingIntegrityService(database: database),
    );
    addTearDown(bloc.close);

    bloc.add(const SettingsCheckIntegrityEvent());
    final state = await bloc.stream.firstWhere((s) => s.errorMessage != null);

    expect(state.isBusy, isFalse);
    expect(state.integrityResult, isNull);
    expect(state.errorMessage, contains('Database check failed'));
  });

  test('without a service the check reports that it is unavailable', () async {
    final bloc = build();
    addTearDown(bloc.close);

    bloc.add(const SettingsCheckIntegrityEvent());
    final state = await bloc.stream.firstWhere((s) => s.errorMessage != null);

    expect(state.errorMessage, 'Database check is unavailable.');
  });
}
