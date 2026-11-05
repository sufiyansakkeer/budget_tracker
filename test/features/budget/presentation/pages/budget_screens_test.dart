import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_surface.dart';
import 'package:monivo/core/dates/date_range_format.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_details_screen.dart';
import 'package:monivo/features/budget/presentation/pages/budget_list_screen.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_list_items.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

/// Budgets whose statistics can be set per budget.
class _StatsBudgetRepository extends ListBudgetRepository {
  final Map<String, MonthlyStatisticsEntity> stats;

  _StatsBudgetRepository(
    super.budgets,
    super.activeId, {
    this.stats = const {},
  });

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => stats[budgetId] ?? MonthlyStatisticsEntity.empty;

  /// As BudgetRepositoryImpl: once the active budget is gone, a budget
  /// running today takes over.
  @override
  Future<String?> getActiveBudgetId() async {
    if (budgets.any((b) => b.id == activeId)) return activeId;
    final open = budgets.where((b) => !b.isArchived).toList();
    if (open.isEmpty) return activeId = null;
    final now = DateTime.now();
    return activeId = open
        .firstWhere((b) => b.isActiveOn(now), orElse: () => open.first)
        .id;
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final source = budgets.firstWhere((b) => b.id == id);
    final copy = source.copyWith(
      id: '${id}_copy',
      name: newName,
      startDate: startDate,
      endDate: endDate,
    );
    budgets.add(copy);
    return copy;
  }

  /// Makes a delete fail, as when the database is busy.
  bool failDelete = false;

  @override
  Future<void> deleteBudget(String id) async {
    if (failDelete) throw Exception('database is locked');
    await super.deleteBudget(id);
  }
}

BudgetEntity _budget(
  String id,
  String name, {
  required DateTime start,
  required DateTime end,
  double amount = 30000,
  double? remaining,
  String currency = 'INR',
  bool archived = false,
}) => BudgetEntity(
  id: id,
  name: name,
  monthlyAmount: amount,
  remainingAmount: remaining ?? amount,
  currency: currency,
  startDate: start,
  endDate: end,
  isArchived: archived,
  createdAt: start,
  updatedAt: start,
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  final household = _budget(
    'household',
    'Household',
    start: day(-8),
    end: day(22),
    amount: 60000,
    remaining: 25103,
  );
  final personal = _budget(
    'personal',
    'Personal',
    start: day(-2),
    end: day(27),
    amount: 9000,
    remaining: 7380,
  );
  final muscat = _budget(
    'muscat',
    'Muscat',
    start: day(-3),
    end: day(26),
    amount: 300,
    remaining: 120.5,
    currency: 'OMR',
  );
  final nextYear = _budget('next', 'Next trip', start: day(40), end: day(60));
  final oldTrip = _budget(
    'old',
    'Old trip',
    start: day(-90),
    end: day(-60),
    archived: true,
  );

  late _StatsBudgetRepository repository;
  late FakeReconcileTabUseCase reconcileTabs;

  Future<void> register(
    List<BudgetEntity> budgets,
    String? activeId, {
    Map<String, MonthlyStatisticsEntity> stats = const {},
    List<BillEntity>? bills,
  }) async {
    await getIt.reset();
    repository = _StatsBudgetRepository(budgets, activeId, stats: stats);
    reconcileTabs = FakeReconcileTabUseCase();
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: repository,
          reconcileTabs: reconcileTabs,
        ),
      )
      ..registerSingleton<BudgetRepository>(repository)
      ..registerSingleton<GetBudgetListSummaryUseCase>(
        GetBudgetListSummaryUseCase(repository: repository),
      );
    if (bills != null) {
      getIt.registerSingleton<GetSafeToSpendUseCase>(
        fakeSafeToSpendUseCase(
          repository,
          billRepository: SafeSpendFakeBillRepository(bills),
        ),
      );
    }
  }

  /// [screen] at [location] under a router, with the budget routes the
  /// screens push to.
  Future<void> pumpRouted(
    WidgetTester tester,
    String location, {
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: GoRouter(
          initialLocation: location,
          routes: [
            GoRoute(
              path: '/app/budgets',
              builder: (_, _) => const BudgetListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (_, state) => Scaffold(
                    body: Text('Form ${state.uri.queryParameters['next']}'),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => BudgetDetailsScreen(
                    budgetId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, state) => Scaffold(
                        body: Text('Edit ${state.pathParameters['id']}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/app/home',
              builder: (_, _) => const Scaffold(body: Text('Home screen')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() => getIt.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(400, 1200),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Budgets list', () {
    testWidgets('the active budget leads as the one raised card, the rest '
        'are compact rows', (tester) async {
      await register([
        personal,
        household,
        muscat,
        nextYear,
        oldTrip,
      ], 'household');
      await pump(tester, const BudgetListScreen());

      expect(find.byType(AppSurface), findsOneWidget);
      expect(find.byType(ActiveBudgetCard), findsOneWidget);
      expect(
        find.text('Home, Expenses and Reports follow this budget'),
        findsOneWidget,
      );
      expect(find.byType(BudgetRow), findsNWidgets(4));
      expect(find.text('Also running today'), findsOneWidget);
      expect(find.text('Starting later'), findsOneWidget);
      expect(find.text('Archived'), findsWidgets);

      // The active card comes first, the footer last.
      final card = tester.getTopLeft(find.byType(ActiveBudgetCard)).dy;
      final rows = tester.getTopLeft(find.text('Also running today')).dy;
      final footer = tester.getTopLeft(find.text('Total remaining')).dy;
      expect(card, lessThan(rows));
      expect(rows, lessThan(footer));
    });

    testWidgets('the footer gives one total per currency, never pooled', (
      tester,
    ) async {
      await register([household, personal, muscat], 'household');
      await pump(tester, const BudgetListScreen());

      expect(
        find.text(AppMoney.format(25103 + 7380, currency: 'INR')),
        findsOneWidget,
      );
      expect(find.text(AppMoney.format(120.5, currency: 'OMR')), findsWidgets);
      expect(find.text('Across 3 budgets running today'), findsOneWidget);
    });

    testWidgets('an overspent budget reads "over", in the critical tone', (
      tester,
    ) async {
      await register([
        household,
        personal.copyWith(remainingAmount: -1200),
      ], 'household');
      await pump(tester, const BudgetListScreen());

      expect(find.text('over'), findsOneWidget);
      expect(find.text(AppMoney.format(1200, currency: 'INR')), findsOneWidget);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
        await register([
          household,
          personal,
          muscat,
          nextYear,
          oldTrip,
        ], 'household');
        await pump(
          tester,
          const BudgetListScreen(),
          size: Size(width, 1600),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Budget details', () {
    testWidgets('the active budget offers "Add expense"', (tester) async {
      await register([household, personal], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      expect(find.byKey(const Key('budgetAddExpense')), findsOneWidget);
      expect(find.byKey(const Key('budgetMakeActive')), findsNothing);
      expect(
        find.text('Home, Expenses and Reports follow this budget'),
        findsOneWidget,
      );
    });

    testWidgets('another budget offers "Make active" instead of adding to '
        'the active one (review: it recorded into the active budget)', (
      tester,
    ) async {
      await register([household, personal], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'personal'));

      expect(find.byKey(const Key('budgetAddExpense')), findsNothing);
      expect(find.text('Not your active budget'), findsOneWidget);

      await tester.tap(find.byKey(const Key('budgetMakeActive')));
      await tester.pumpAndSettle();
      expect(repository.activeId, 'personal');
      expect(find.byKey(const Key('budgetAddExpense')), findsOneWidget);
    });

    testWidgets('after a failed delete the screen still follows changes', (
      tester,
    ) async {
      await register([household, personal], 'household');
      repository.failDelete = true;
      await pump(tester, const BudgetDetailsScreen(budgetId: 'personal'));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't delete the budget."), findsOne);

      // Renamed elsewhere: the details screen picks it up.
      final index = repository.budgets.indexWhere((b) => b.id == 'personal');
      repository.budgets[index] = personal.copyWith(name: 'Renamed');
      RefreshBuses.budgets.notifyChanged();
      await tester.pumpAndSettle();

      expect(find.text('Renamed'), findsWidgets);
    });

    group('delete confirmation with Pay later purchases', () {
      Future<void> openDelete(WidgetTester tester) async {
        await pump(tester, const BudgetDetailsScreen(budgetId: 'personal'));
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
      }

      const tabLine =
          '3 purchases on Pay later tabs will be removed from their tabs; '
          'any money paid on them moves to other purchases or stays as '
          'credit.';

      testWidgets('names the tab purchases inside the budget and tells '
          'Pay later screens after the delete', (tester) async {
        await register([household, personal], 'household');
        reconcileTabs.purchasesInBudget = 3;
        var payLaterNotices = 0;
        final subscription = RefreshBuses.payLater.changes.listen(
          (_) => payLaterNotices++,
        );
        addTearDown(subscription.cancel);
        // A real router, so the screen can pop once the budget is gone.
        tester.view.physicalSize = const Size(400, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: GoRouter(
              initialLocation: '/budget',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const Scaffold(body: Text('Budgets')),
                  routes: [
                    GoRoute(
                      path: 'budget',
                      builder: (_, _) =>
                          const BudgetDetailsScreen(budgetId: 'personal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        expect(find.textContaining(tabLine), findsOneWidget);
        expect(
          reconcileTabs.calls,
          contains('countPurchasesInBudget:personal'),
        );

        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(reconcileTabs.calls, contains('aroundBudgetDelete:personal'));
        expect(repository.budgets.any((b) => b.id == 'personal'), isFalse);
        expect(find.text('Budget deleted'), findsOneWidget);
        expect(find.text('Budgets'), findsOneWidget);
        expect(payLaterNotices, 1);
      });

      testWidgets('says "1 purchase" in the singular', (tester) async {
        await register([household, personal], 'household');
        reconcileTabs.purchasesInBudget = 1;
        await openDelete(tester);

        expect(
          find.textContaining(
            '1 purchase on a Pay later tab will be removed from its tab; '
            'any money paid on it moves to other purchases or stays as '
            'credit.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('leaves the line out when there are none', (tester) async {
        await register([household, personal], 'household');
        var payLaterNotices = 0;
        final subscription = RefreshBuses.payLater.changes.listen(
          (_) => payLaterNotices++,
        );
        addTearDown(subscription.cancel);
        await openDelete(tester);

        expect(find.text('Delete this budget?'), findsOneWidget);
        expect(find.textContaining('Pay later'), findsNothing);

        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(payLaterNotices, 0);
      });

      testWidgets('still asks, without the line, when the count fails', (
        tester,
      ) async {
        await register([household, personal], 'household');
        reconcileTabs.countError = StateError('database is locked');
        var payLaterNotices = 0;
        final subscription = RefreshBuses.payLater.changes.listen(
          (_) => payLaterNotices++,
        );
        addTearDown(subscription.cancel);
        await openDelete(tester);

        expect(find.text('Delete this budget?'), findsOneWidget);
        expect(find.textContaining('Pay later'), findsNothing);

        // The delete still runs, reconciling tabs, and Pay later screens
        // are told (the count is unknown, so tabs may have changed).
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(reconcileTabs.calls, contains('aroundBudgetDelete:personal'));
        expect(repository.budgets.any((b) => b.id == 'personal'), isFalse);
        expect(payLaterNotices, 1);
      });
    });

    testWidgets('an archived budget offers neither, only Restore', (
      tester,
    ) async {
      await register([household, oldTrip], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'old'));

      expect(find.byKey(const Key('budgetAddExpense')), findsNothing);
      expect(find.byKey(const Key('budgetMakeActive')), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('shows what is left on one surface with plain figures', (
      tester,
    ) async {
      await register(
        [household],
        'household',
        stats: {
          'household': const MonthlyStatisticsEntity(
            totalSpent: 34897,
            expenseCount: 21,
            todaySpending: 570,
          ),
        },
      );
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      expect(find.byType(AppSurface), findsOneWidget);
      expect(
        find.text(AppMoney.format(25103, currency: 'INR')),
        findsOneWidget,
      );
      expect(find.text('Spent today, incl. bills'), findsOneWidget);
      expect(find.text(AppMoney.format(570, currency: 'INR')), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.textContaining('58% used'), findsOneWidget);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
        await register([household, personal], 'household');
        await pump(
          tester,
          const BudgetDetailsScreen(budgetId: 'personal'),
          size: Size(width, 1600),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  final september = _budget(
    'sep',
    'September',
    start: day(-40),
    end: day(-10),
    remaining: 2000,
  );

  group('UX-021 · an ended active budget', () {
    testWidgets('the list says it ended and titles running ones "Running '
        'today"', (tester) async {
      await register([september, personal], 'sep');
      await pump(tester, const BudgetListScreen());

      expect(find.text('Active · Ended'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      expect(find.text('Running today'), findsOneWidget);
      expect(find.text('Also running today'), findsNothing);
      expect(
        find.widgetWithText(TextButton, 'Start next period'),
        findsOneWidget,
      );
    });

    testWidgets('details show the phase beside "Active"', (tester) async {
      await register([september, personal], 'sep');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'sep'));

      expect(find.text('Active · Ended'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Start next period'),
        findsOneWidget,
      );
    });

    testWidgets('a running active budget is plainly "Active"', (tester) async {
      await register([household, personal], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Start next period'), findsNothing);
    });
  });

  group('ended and set-aside states fit at 320dp with 200% text', () {
    testWidgets('the list with an ended active budget', (tester) async {
      await register([september, personal, household], 'sep');
      await pump(
        tester,
        const BudgetListScreen(),
        size: const Size(320, 1800),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('details of an ended active budget', (tester) async {
      await register(
        [september.copyWith(reservedAmount: 500), personal],
        'sep',
        bills: const [],
      );
      await pump(
        tester,
        const BudgetDetailsScreen(budgetId: 'sep'),
        size: const Size(320, 2400),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the archive dialog with a budget to switch to', (
      tester,
    ) async {
      await register([household, personal], 'household');
      await pump(
        tester,
        const BudgetDetailsScreen(budgetId: 'household'),
        size: const Size(320, 1600),
        textScale: 2,
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive and switch to Personal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UX-022 · Start next period', () {
    testWidgets('the Ended group offers it and opens the prefilled form', (
      tester,
    ) async {
      await register([household, september], 'household');
      await pumpRouted(tester, '/app/budgets');

      await tester.tap(find.widgetWithText(TextButton, 'Start next period'));
      await tester.pumpAndSettle();
      expect(find.text('Form sep'), findsOneWidget);
    });

    testWidgets('details of an ended budget offer it', (tester) async {
      await register([household, september], 'household');
      await pumpRouted(tester, '/app/budgets/sep');

      await tester.tap(find.widgetWithText(TextButton, 'Start next period'));
      await tester.pumpAndSettle();
      expect(find.text('Form sep'), findsOneWidget);
    });

    testWidgets('Duplicate shows the dates, needs a name and opens the copy', (
      tester,
    ) async {
      await register([household], 'household');
      await pumpRouted(tester, '/app/budgets/household');

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(
            formatDateRange(household.startDate, household.endDate),
          ),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '  ');
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Duplicate');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Household copy');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(repository.budgets.map((b) => b.id), contains('household_copy'));
      expect(find.text('Household copy'), findsOneWidget);
    });
  });

  group('UX-037 · Change amount on details', () {
    testWidgets('details offer it and it opens the edit form', (tester) async {
      await register([household], 'household');
      await pumpRouted(tester, '/app/budgets/household');

      final button = find.widgetWithText(TextButton, 'Change amount');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Edit household'), findsOneWidget);
    });
  });

  group('UX-047 · day counts that agree', () {
    // 9 + 23 is 32 for a 31-day budget: today is counted in both.
    testWidgets('the list and details say the days left include today', (
      tester,
    ) async {
      await register([household], 'household');
      await pumpRouted(tester, '/app/budgets');
      expect(
        find.text('Day 9 of 31 · 23 days left, incl.\u00A0today'),
        findsOneWidget,
      );

      await pumpRouted(tester, '/app/budgets/household');
      expect(
        find.textContaining('Day 9 of 31 · 23 days left, incl.\u00A0today'),
        findsOneWidget,
      );
    });
  });

  group('UX-029 · what is set aside', () {
    final linkedBill = BillEntity(
      id: 'rent',
      title: 'Rent',
      amount: 1500,
      currency: 'INR',
      category: BillCategory.utilities,
      dueDate: day(5),
      budgetId: 'household',
      createdAt: today,
      updatedAt: today,
    );

    testWidgets('details list kept aside, the savings goal and bills due, '
        'read-only, with a link to Home', (tester) async {
      await register(
        [household.copyWith(reservedAmount: 2000)],
        'household',
        bills: [linkedBill],
      );
      await pumpRouted(tester, '/app/budgets/household');

      expect(find.text('Set aside'), findsOneWidget);
      expect(find.text('Kept aside'), findsOneWidget);
      expect(find.text(AppMoney.format(2000, currency: 'INR')), findsOneWidget);
      expect(find.text('Savings goal'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('Bills due'), findsOneWidget);
      expect(find.text(AppMoney.format(1500, currency: 'INR')), findsOneWidget);
      // Still one raised surface.
      expect(find.byType(AppSurface), findsOneWidget);

      await tester.tap(find.text("See Today's Safe Spending on Home"));
      await tester.pumpAndSettle();
      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('another budget has no link to Home', (tester) async {
      await register([household, personal], 'household', bills: const []);
      await pump(tester, const BudgetDetailsScreen(budgetId: 'personal'));

      expect(find.text('Set aside'), findsOneWidget);
      expect(find.text("See Today's Safe Spending on Home"), findsNothing);
    });
  });

  group('UX-035 · archiving or deleting the active budget', () {
    Future<void> archive(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
    }

    testWidgets('always asks, and Undo restores it', (tester) async {
      await register([household, nextYear], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      await archive(tester);
      expect(find.text('Archive your active budget?'), findsOneWidget);
      expect(find.textContaining('Archive and switch'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(
        repository.budgets.firstWhere((b) => b.id == 'household').isArchived,
        isTrue,
      );
      expect(find.text('Budget archived'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(
        repository.budgets.firstWhere((b) => b.id == 'household').isArchived,
        isFalse,
      );
      expect(repository.activeId, 'household');
    });

    testWidgets('offers to switch to a running budget; Undo switches back', (
      tester,
    ) async {
      await register([household, personal], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      await archive(tester);
      await tester.tap(find.text('Archive and switch to Personal'));
      await tester.pumpAndSettle();

      expect(
        repository.budgets.firstWhere((b) => b.id == 'household').isArchived,
        isTrue,
      );
      expect(repository.activeId, 'personal');
      expect(
        find.text('Budget archived. Personal is now active.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(
        repository.budgets.firstWhere((b) => b.id == 'household').isArchived,
        isFalse,
      );
      expect(repository.activeId, 'household');
    });

    testWidgets('deleting it names the budget Home switches to', (
      tester,
    ) async {
      await register([household, personal], 'household');
      await pumpRouted(tester, '/app/budgets/household');

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Home will switch to "Personal".'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Budget deleted. Personal is now active.'),
        findsOneWidget,
      );
    });
  });
}
