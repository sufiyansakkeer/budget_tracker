import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_analytics_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_overview_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tabs_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/manage_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_payment_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_purchase_usecase.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_overview_bloc.dart';
import 'package:monivo/features/pay_later/presentation/bloc/tab_detail_bloc.dart';
import 'package:monivo/features/pay_later/data/services/tab_reminder_service.dart';
import 'package:monivo/features/pay_later/presentation/open_tab_from_notification.dart';
import 'package:monivo/features/settings/domain/services/notification_service.dart';

import '../../helpers/in_memory_database.dart';

/// Stands in for the registered reminder service and counts re-schedules.
class _RecordingTabReminders implements TabReminderService {
  int rescheduleAllCalls = 0;

  @override
  Future<void> rescheduleAll() async => rescheduleAllCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => getIt.reset());

  // Registrations are lazy, so a wrong dependency would otherwise only fail
  // the first time a screen asked for it.
  test('every registration can be created', () async {
    await initDependencyInjection(database: await createInMemoryDatabase());

    final created = getIt.findAll<Object>(
      instantiateLazySingletons: true,
      callFactories: true,
    );

    expect(created, isNotEmpty);
    for (final object in created) {
      if (object is BlocBase) await object.close();
    }
  });

  // Pay Later collaborators are required, never defaulted: the objects the
  // app builds hold the registered singletons.
  test(
    'expenses and budget delete use the registered pay later use cases',
    () async {
      await initDependencyInjection(database: await createInMemoryDatabase());

      final bloc = getIt<ExpenseBloc>();
      addTearDown(bloc.close);
      expect(identical(bloc.tabPurchases, getIt<TabPurchaseUseCase>()), isTrue);
      expect(
        identical(
          getIt<ManageBudgetUseCase>().reconcileTabs,
          getIt<ReconcileTabUseCase>(),
        ),
        isTrue,
      );
      expect(getIt.isRegistered<ManageTabUseCase>(), isTrue);
      expect(getIt.isRegistered<GetTabLedgerUseCase>(), isTrue);
      expect(getIt.isRegistered<GetTabsUseCase>(), isTrue);
      expect(getIt.isRegistered<TabPaymentUseCase>(), isTrue);
    },
  );

  test('the pay later overview is wired to the registered use cases', () async {
    await initDependencyInjection(database: await createInMemoryDatabase());

    final bloc = getIt<PayLaterOverviewBloc>();
    addTearDown(bloc.close);
    expect(
      identical(bloc.getOverview, getIt<GetPayLaterOverviewUseCase>()),
      isTrue,
    );
    expect(
      identical(bloc.getAnalytics, getIt<GetPayLaterAnalyticsUseCase>()),
      isTrue,
    );
    // A factory: each screen gets its own bloc (and closes it).
    final other = getIt<PayLaterOverviewBloc>();
    addTearDown(other.close);
    expect(identical(bloc, other), isFalse);
  });

  test('the tab detail bloc is wired to the registered use cases', () async {
    await initDependencyInjection(database: await createInMemoryDatabase());

    final bloc = getIt<TabDetailBloc>();
    addTearDown(bloc.close);
    expect(identical(bloc.getLedger, getIt<GetTabLedgerUseCase>()), isTrue);
    expect(identical(bloc.payments, getIt<TabPaymentUseCase>()), isTrue);
    expect(identical(bloc.manageTab, getIt<ManageTabUseCase>()), isTrue);
    expect(
      identical(bloc.getAnalytics, getIt<GetPayLaterAnalyticsUseCase>()),
      isTrue,
    );
    expect(
      identical(bloc.getCategories, getIt<GetCategoriesUseCase>()),
      isTrue,
    );
    final other = getIt<TabDetailBloc>();
    addTearDown(other.close);
    expect(identical(bloc, other), isFalse);
  });

  // Nested `database.transaction` calls only join when every datasource holds
  // the same AppDatabase instance.
  test('datasources share the one injected database', () async {
    final AppDatabase db = await createInMemoryDatabase();
    await initDependencyInjection(database: db);

    final payLater =
        getIt<PayLaterLocalDataSource>() as PayLaterLocalDataSourceImpl;
    final expense =
        getIt<ExpenseLocalDataSource>() as ExpenseLocalDataSourceImpl;
    final budget = getIt<BudgetLocalDataSource>() as BudgetLocalDataSourceImpl;

    expect(identical(payLater.database, db), isTrue);
    expect(identical(expense.database, db), isTrue);
    expect(identical(budget.database, db), isTrue);
  });

  // Clearing the schedule (every expense, budget or bill change) also
  // clears the Pay later reminders, so NotificationService must put them
  // back through the TabReminderService the app registered.
  test('notification service restores tab reminders through the registered '
      'reminder service, and a tap opens the tab', () async {
    await initDependencyInjection(database: await createInMemoryDatabase());

    final reminders = getIt<TabReminderService>();
    expect(identical(reminders, getIt<TabReminderService>()), isTrue);
    expect(identical(reminders.getTabs, getIt<GetTabsUseCase>()), isTrue);
    expect(
      identical(reminders.getLedger, getIt<GetTabLedgerUseCase>()),
      isTrue,
    );

    final recorder = _RecordingTabReminders();
    await getIt.unregister<TabReminderService>();
    getIt.registerSingleton<TabReminderService>(recorder);

    final notifications = getIt<NotificationService>();
    await notifications.rescheduleTabReminders();
    expect(recorder.rescheduleAllCalls, 1);
    expect(
      identical(notifications.onPayLaterTap, openTabFromNotification),
      isTrue,
    );
  });
}
