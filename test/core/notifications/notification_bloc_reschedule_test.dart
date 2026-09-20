import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/notifications/notification_bloc.dart';
import 'package:monivo/core/notifications/notification_state.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/notification_service.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:monivo/features/settings/domain/repository/settings_repository.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';

import '../../features/dashboard/domain/usecases/get_spending_targets_usecase_test.dart'
    show FakeBudgetRepository;

/// Records scheduling calls instead of talking to the platform.
class RecordingNotificationService extends NotificationService {
  RecordingNotificationService(FakeBudgetRepository repository)
    : super(
        budgetRepository: repository,
        calculationService: BudgetCalculationService(),
        spendingTargetsUseCase: GetSpendingTargetsUseCase(
          repository: repository,
          calculationService: BudgetCalculationService(),
        ),
      );

  int scheduleCount = 0;
  AppSettings? lastSettings;
  bool throwOnSchedule = false;

  @override
  Future<void> scheduleAll(AppSettings settings) async {
    if (throwOnSchedule) throw Exception('platform unavailable');
    scheduleCount++;
    lastSettings = settings;
  }
}

class FakeSettingsRepository implements SettingsRepository {
  AppSettings settings;
  FakeSettingsRepository(this.settings);

  @override
  Future<AppSettings> loadSettings() async => settings;
  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}
  @override
  Future<void> setPalette(ColorPalette palette) async {}
  @override
  Future<void> setCurrency(String code, String symbol) async {}
  @override
  Future<void> setNotificationSettings(NotificationSettings s) async {}
  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
  @override
  Future<void> setFirstLaunchCompleted() async {}
}

void main() {
  const debounce = Duration(milliseconds: 20);
  late RecordingNotificationService service;
  late FakeSettingsRepository settingsRepository;

  NotificationBloc build({NotificationStatus? seedStatus}) {
    final bloc = NotificationBloc(
      notificationService: service,
      loadSettingsUseCase: LoadSettingsUseCase(repository: settingsRepository),
      rescheduleDebounce: debounce,
    );
    if (seedStatus != null) {
      bloc.emit(NotificationState(status: seedStatus));
    }
    return bloc;
  }

  setUp(() {
    service = RecordingNotificationService(FakeBudgetRepository());
    settingsRepository = FakeSettingsRepository(
      const AppSettings(
        notifications: NotificationSettings(notificationsEnabled: true),
      ),
    );
  });

  test('re-schedules once after a burst of expense changes', () async {
    final bloc = build(seedStatus: NotificationStatus.ready);
    addTearDown(bloc.close);

    RefreshBuses.expenses.notifyChanged();
    RefreshBuses.expenses.notifyChanged();
    RefreshBuses.budgets.notifyChanged();
    await Future<void>.delayed(debounce * 4);

    expect(service.scheduleCount, 1);
    expect(service.lastSettings, settingsRepository.settings);
  });

  test('does nothing before notifications are ready', () async {
    final bloc = build();
    addTearDown(bloc.close);

    RefreshBuses.expenses.notifyChanged();
    await Future<void>.delayed(debounce * 4);

    expect(service.scheduleCount, 0);
  });

  test('does nothing when the user turned notifications off', () async {
    settingsRepository.settings = const AppSettings(
      notifications: NotificationSettings(notificationsEnabled: false),
    );
    final bloc = build(seedStatus: NotificationStatus.ready);
    addTearDown(bloc.close);

    RefreshBuses.expenses.notifyChanged();
    await Future<void>.delayed(debounce * 4);

    expect(service.scheduleCount, 0);
  });

  test('a scheduling failure never breaks the bloc', () async {
    service.throwOnSchedule = true;
    final bloc = build(seedStatus: NotificationStatus.ready);
    addTearDown(bloc.close);

    RefreshBuses.expenses.notifyChanged();
    await Future<void>.delayed(debounce * 4);

    expect(bloc.state.status, NotificationStatus.ready);
  });

  test('a closed bloc stops listening', () async {
    final bloc = build(seedStatus: NotificationStatus.ready);
    await bloc.close();

    RefreshBuses.expenses.notifyChanged();
    await Future<void>.delayed(debounce * 4);

    expect(service.scheduleCount, 0);
  });

  test('settings failures are ignored', () async {
    final bloc = NotificationBloc(
      notificationService: service,
      loadSettingsUseCase: _FailingLoadSettings(),
      rescheduleDebounce: debounce,
    );
    addTearDown(bloc.close);
    bloc.emit(const NotificationState(status: NotificationStatus.ready));

    RefreshBuses.expenses.notifyChanged();
    await Future<void>.delayed(debounce * 4);

    expect(service.scheduleCount, 0);
    expect(bloc.state.status, NotificationStatus.ready);
  });
}

class _FailingLoadSettings implements LoadSettingsUseCase {
  @override
  SettingsRepository get repository => throw UnimplementedError();

  @override
  Future<SettingsResult<AppSettings>> call() async => const SettingsError(
    SettingsFailure(type: SettingsErrorType.loadFailure, message: 'nope'),
  );
}
