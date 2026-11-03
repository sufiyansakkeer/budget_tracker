import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/manage_tab_usecase.dart';
import 'package:monivo/features/pay_later/presentation/bloc/tab_form_cubit.dart';
import 'package:monivo/features/pay_later/presentation/pages/tab_form_screen.dart';

import '../../../helpers/bill_ui_fakes.dart';
import '../../../helpers/pay_later_fakes.dart';
import '../../../helpers/pay_later_fixtures.dart';

class _FakeManageTab implements ManageTabUseCase {
  final List<PayLaterTab> created = [];
  final List<PayLaterTab> updated = [];
  PayLaterFailure? failWith;

  @override
  Future<PayLaterResult<PayLaterTab>> create(PayLaterTab tab) async {
    if (failWith != null) return PayLaterError(failWith!);
    created.add(tab);
    return PayLaterSuccess(tab);
  }

  @override
  Future<PayLaterResult<PayLaterTab>> update(PayLaterTab tab) async {
    if (failWith != null) return PayLaterError(failWith!);
    updated.add(tab);
    return PayLaterSuccess(tab);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Just enough repository for the real [ManageTabUseCase.update].
class _MemoryTabRepository implements PayLaterRepository {
  PayLaterTab tab;
  _MemoryTabRepository(this.tab);

  @override
  Future<PayLaterTab?> getTab(String id) async => tab;

  @override
  Future<bool> tabHasActivity(String id) async => false;

  @override
  Future<void> updateTab(PayLaterTab updated) async => tab = updated;

  /// Tab writes check and write in one transaction; nothing to roll back.
  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeLedger implements GetTabLedgerUseCase {
  final PayLaterTab? tab;
  final bool used;
  _FakeLedger({this.tab, this.used = false});

  @override
  Future<PayLaterResult<TabLedger>> call(String tabId) async {
    final t = tab;
    if (t == null) {
      return const PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.notFound,
          message: 'Tab not found',
        ),
      );
    }
    return PayLaterSuccess(
      TabLedger(
        tab: t,
        purchases: used
            ? [
                PurchaseLine(
                  expense: payLaterExpense('e1'),
                  paid: 0,
                  owes: 5,
                  status: PurchaseStatus.unpaid,
                  period: null,
                ),
              ]
            : const [],
        payments: const [],
        periods: const [],
        owed: 0,
        credit: 0,
        overdue: 0,
        nextSettleUp: null,
        totalAdded: 0,
        totalPaid: 0,
        asOf: DateTime(2026, 11, 2),
      ),
    );
  }
}

class _FakeCategories implements GetCategoriesUseCase {
  @override
  Future<ExpenseResult<List<ExpenseCategory>>> call() async =>
      const ExpenseSuccess([
        ExpenseCategory(
          id: 'food',
          name: 'Food',
          icon: 'restaurant',
          colorHex: '#FF0000',
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

BudgetEntity _budget(String currency) => BudgetEntity(
  id: 'b1',
  name: 'Household',
  monthlyAmount: 100,
  remainingAmount: 100,
  currency: currency,
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2099, 12, 31),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late _FakeManageTab manage;

  TabFormCubit cubit({
    ManageTabUseCase? manageTab,
    PayLaterTab? existing,
    bool used = false,
    List<BudgetEntity> budgets = const [],
  }) => TabFormCubit(
    manageTab: manageTab ?? manage,
    getLedger: _FakeLedger(tab: existing, used: used),
    getCategories: _FakeCategories(),
    manageBudget: ManageBudgetUseCase(
      repository: ListBudgetRepository(
        budgets,
        budgets.isEmpty ? null : budgets.first.id,
      ),
      reconcileTabs: FakeReconcileTabUseCase(),
    ),
    appCurrency: () => 'USD',
  );

  setUp(() => manage = _FakeManageTab());

  Future<TabFormCubit> pump(
    WidgetTester tester, {
    String? tabId,
    String? currency,
    PayLaterTab? existing,
    ManageTabUseCase? manageTab,
    bool used = false,
    List<BudgetEntity> budgets = const [],
  }) async {
    final c = cubit(
      manageTab: manageTab,
      existing: existing,
      used: used,
      budgets: budgets,
    );
    addTearDown(c.close);
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider.value(
            value: c,
            child: TabFormScreen(tabId: tabId, currency: currency),
          ),
        ),
        GoRoute(
          path: AppRouter.payLaterPath,
          builder: (_, _) => const Scaffold(body: Text('Pay later')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> pickRhythm(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.byKey(const Key('tabRhythmPicker')));
    await tester.tap(find.byKey(const Key('tabRhythmPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tabSaveButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('saving every 14 days stores anchor today', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('tabNameField')), ' Cafe ');
    await pickRhythm(tester, 'Every 14 days');
    await save(tester);

    expect(manage.created, hasLength(1));
    final tab = manage.created.single;
    expect(tab.name, 'Cafe');
    expect(tab.rhythm, EveryDays(days: 14, anchor: DateTime.now().dateOnly));
    expect(tab.id, isNotEmpty);
  });

  group('reminder switch (T10)', () {
    SwitchListTile reminder(WidgetTester tester) => tester
        .widget<SwitchListTile>(find.byKey(const Key('tabReminderSwitch')));

    testWidgets('on demand: off, disabled, and says why', (tester) async {
      await pump(tester);
      await pickRhythm(tester, 'On demand');

      expect(reminder(tester).onChanged, isNull);
      expect(reminder(tester).value, isFalse);
      expect(
        find.text('On demand has no settle-up day to remind you about.'),
        findsOneWidget,
      );
    });

    testWidgets('pick a date with no date: disabled until a date is set', (
      tester,
    ) async {
      await pump(tester);
      await pickRhythm(tester, 'Pick a date');

      expect(reminder(tester).onChanged, isNull);
      expect(
        find.text('Pick a settle-up date to get a reminder.'),
        findsOneWidget,
      );

      await pickRhythm(tester, 'Every 7 days');
      expect(reminder(tester).onChanged, isNotNull);
      expect(find.text('Before the settle-up day'), findsOneWidget);
    });

    testWidgets('a reminder that can never fire is not saved as on', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('tabNameField')), 'Cafe');
      await pickRhythm(tester, 'Every 7 days');
      await tester.ensureVisible(find.byKey(const Key('tabReminderSwitch')));
      await tester.tap(find.byKey(const Key('tabReminderSwitch')));
      await tester.pumpAndSettle();
      expect(reminder(tester).value, isTrue);

      await pickRhythm(tester, 'On demand');
      await save(tester);

      expect(manage.created.single.reminderEnabled, isFalse);
    });
  });

  testWidgets('custom days validates 1-365', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('tabNameField')), 'Shop');
    await pickRhythm(tester, 'Custom days');

    for (final bad in ['0', '366']) {
      await tester.enterText(find.byKey(const Key('tabCustomDaysField')), bad);
      await save(tester);
      expect(
        find.text('Enter a number of days from 1 to 365.'),
        findsOneWidget,
      );
      expect(manage.created, isEmpty);
    }

    await tester.enterText(find.byKey(const Key('tabCustomDaysField')), '365');
    await save(tester);
    expect((manage.created.single.rhythm as EveryDays).days, 365);
  });

  testWidgets('an empty name is refused before saving', (tester) async {
    await pump(tester);
    await save(tester);
    expect(find.text('Enter a name of 1 to 100 characters.'), findsOneWidget);
    expect(manage.created, isEmpty);
  });

  testWidgets('currency defaults to the query', (tester) async {
    await pump(tester, currency: 'GBP', budgets: [_budget('OMR')]);
    expect(find.textContaining('GBP'), findsOneWidget);
  });

  testWidgets('currency defaults to the active budget', (tester) async {
    await pump(tester, budgets: [_budget('OMR')]);
    expect(find.textContaining('OMR'), findsOneWidget);
  });

  testWidgets('currency falls back to the app currency', (tester) async {
    await pump(tester);
    expect(find.textContaining('USD'), findsOneWidget);
  });

  testWidgets('currency locked for a used tab', (tester) async {
    await pump(tester, tabId: 't1', existing: payLaterTab('t1'), used: true);
    expect(find.textContaining('Locked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tabCurrencyField')));
    await tester.pumpAndSettle();
    expect(find.text('Search by name or code'), findsNothing);
  });

  testWidgets('currency can change for an unused tab', (tester) async {
    await pump(tester, tabId: 't1', existing: payLaterTab('t1'));
    await tester.tap(find.byKey(const Key('tabCurrencyField')));
    await tester.pumpAndSettle();
    expect(find.text('Search by name or code'), findsOneWidget);
  });

  // The form is pushed on top of another page, as in the app: picking a
  // currency must close only the sheet, never the form under it.
  group('currency picker on a pushed form', () {
    Future<TabFormCubit> pumpPushed(
      WidgetTester tester, {
      String? tabId,
      PayLaterTab? existing,
      ThemeData? theme,
    }) async {
      // Tall enough that every field stays built (the form is a lazy list).
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = cubit(existing: existing);
      addTearDown(c.close);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/form'),
                child: const Text('Open'),
              ),
            ),
          ),
          GoRoute(
            path: '/form',
            builder: (_, _) => BlocProvider.value(
              value: c,
              child: TabFormScreen(tabId: tabId),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: theme ?? AppTheme.lightTheme,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> openPicker(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('tabCurrencyField')));
      await tester.tap(find.byKey(const Key('tabCurrencyField')));
      await tester.pumpAndSettle();
    }

    Future<void> pickCurrency(WidgetTester tester, String name) async {
      await openPicker(tester);
      expect(find.text('Search by name or code'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, name);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pumpAndSettle();
    }

    Future<void> fillEverything(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('tabNameField')), 'Grocer');
      await tester.tap(find.byKey(const Key('tabCategory_groceries')));
      await tester.pumpAndSettle();
      await pickRhythm(tester, 'Every 14 days');
      await tester.ensureVisible(find.byKey(const Key('tabReminderSwitch')));
      await tester.tap(find.byKey(const Key('tabReminderSwitch')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('tabDefaultCategory')));
      await tester.tap(find.byKey(const Key('tabDefaultCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tabContactField')),
        'Ali, 9123',
      );
      await tester.enterText(find.byKey(const Key('tabNoteField')), 'Shop 4');
      await tester.pumpAndSettle();
    }

    void expectEverythingKept(WidgetTester tester) {
      expect(find.text('New tab'), findsOneWidget);
      expect(find.text('Grocer'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('tabCategory_groceries')))
            .selected,
        isTrue,
      );
      expect(find.text('Every 14 days'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('tabReminderSwitch')))
            .value,
        isTrue,
      );
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Ali, 9123'), findsOneWidget);
      expect(find.text('Shop 4'), findsOneWidget);
    }

    for (final (label, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('picking a currency keeps the form open and filled '
          '($label)', (tester) async {
        await pumpPushed(tester, theme: theme);
        await fillEverything(tester);

        await pickCurrency(tester, 'Euro');

        expect(find.text('Search by name or code'), findsNothing);
        expect(find.byKey(const Key('tabCurrencyField')), findsOneWidget);
        expect(find.textContaining('EUR'), findsOneWidget);
        expect(find.text('Open'), findsNothing);
        expectEverythingKept(tester);

        await save(tester);
        final tab = manage.created.single;
        expect(tab.currency, 'EUR');
        expect(tab.name, 'Grocer');
        expect(tab.category, PayLaterTabCategory.groceries);
        expect(
          tab.rhythm,
          EveryDays(days: 14, anchor: DateTime.now().dateOnly),
        );
        expect(tab.reminderEnabled, isTrue);
        expect(tab.defaultCategoryId, 'food');
        expect(tab.contact, 'Ali, 9123');
        expect(tab.note, 'Shop 4');
        // Saving pops the form, back to the page it was opened from.
        expect(find.text('Open'), findsOneWidget);
      });
    }

    testWidgets('closing the picker without choosing changes nothing', (
      tester,
    ) async {
      await pumpPushed(tester);
      await fillEverything(tester);
      final before = find.textContaining('USD');
      expect(before, findsOneWidget);

      await openPicker(tester);
      await tester.tapAt(const Offset(20, 20)); // the scrim above the sheet
      await tester.pumpAndSettle();

      expect(find.text('Search by name or code'), findsNothing);
      expect(find.textContaining('USD'), findsOneWidget);
      expectEverythingKept(tester);
    });

    testWidgets('edit tab: picking a currency keeps the form open', (
      tester,
    ) async {
      await pumpPushed(
        tester,
        tabId: 't1',
        existing: payLaterTab('t1', name: 'Old'),
      );

      await pickCurrency(tester, 'Euro');

      expect(find.text('Edit tab'), findsOneWidget);
      expect(find.textContaining('EUR'), findsOneWidget);
      expect(find.text('Old'), findsOneWidget);
      await save(tester);
      expect(manage.updated.single.currency, 'EUR');
      expect(manage.updated.single.id, 't1');
    });
  });

  testWidgets('editing keeps the tab id and updates', (tester) async {
    await pump(
      tester,
      tabId: 't1',
      existing: payLaterTab(
        't1',
        rhythm: const MonthlyDay(day: 5),
        name: 'Old',
      ),
    );
    expect(find.text('Old'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tabNameField')), 'New');
    await save(tester);
    expect(manage.updated.single.id, 't1');
    expect(manage.updated.single.name, 'New');
    expect(manage.updated.single.rhythm, const MonthlyDay(day: 5));
  });

  testWidgets('editing a passed pick-a-date tab to a new date saves the old '
      'date as the anchor', (tester) async {
    final now = DateTime.now();
    final old = DateTime(now.year, now.month, now.day - 10);
    final stored = payLaterTab(
      't1',
      rhythm: ManualDate(nextSettleDate: old, anchor: DateTime(2020, 1, 1)),
    );
    final repo = _MemoryTabRepository(stored);
    await pump(
      tester,
      tabId: 't1',
      existing: stored,
      manageTab: ManageTabUseCase(repository: repo),
    );
    await tester.ensureVisible(find.byKey(const Key('tabSettleDateField')));
    await tester.tap(find.byKey(const Key('tabSettleDateField')));
    await tester.pumpAndSettle();
    // The picker opens on the old date; choose the day after it.
    final picked = DateTime(old.year, old.month, old.day + 1);
    if (picked.month != old.month) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${picked.day}').first);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await save(tester);

    final saved = repo.tab.rhythm as ManualDate;
    expect(
      saved.nextSettleDate,
      DateTime(picked.year, picked.month, picked.day),
    );
    expect(saved.anchor, old);
  });

  testWidgets('a missing tab says so', (tester) async {
    await pump(tester, tabId: 'gone');
    expect(find.text('Tab not found'), findsOneWidget);
  });

  testWidgets('a failed save shows calm copy, never the raw error', (
    tester,
  ) async {
    manage.failWith = const PayLaterFailure(
      type: PayLaterErrorType.databaseFailure,
      message: 'Failed to create tab: SqliteException(1)',
    );
    await pump(tester);
    await tester.enterText(find.byKey(const Key('tabNameField')), 'Shop');
    await save(tester);
    expect(find.text(TabFormCubit.saveFailedMessage), findsOneWidget);
    expect(find.textContaining('Sqlite'), findsNothing);
  });

  testWidgets('a successful save notifies the pay later bus', (tester) async {
    var notified = 0;
    final sub = RefreshBuses.payLater.changes.listen((_) => notified++);
    addTearDown(sub.cancel);
    await pump(tester);
    await tester.enterText(find.byKey(const Key('tabNameField')), 'Shop');
    await save(tester);
    expect(notified, 1);
  });

  testWidgets('new route pops the created id', (tester) async {
    final c = cubit();
    addTearDown(c.close);
    String? result = 'unset';
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await context.push<String>(
                '${AppRouter.payLaterPath}/new?currency=OMR',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        GoRoute(
          path: '${AppRouter.payLaterPath}/new',
          builder: (_, state) => BlocProvider.value(
            value: c,
            child: TabFormScreen(
              currency: state.uri.queryParameters['currency'],
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('OMR'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tabNameField')), 'Shop');
    await save(tester);
    expect(result, manage.created.single.id);
  });
}
