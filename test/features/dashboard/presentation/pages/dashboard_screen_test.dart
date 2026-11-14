import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/tomorrow_card.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_ring.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/notifications/notification_permission_notice.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/fade_slide_in.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_breakdown_card.dart';
import 'package:monivo/features/pay_later/presentation/bloc/pay_later_summary_cubit.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/repository/settings_repository.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/safe_to_spend_fixtures.dart';
import '../../../pay_later/presentation/fake_pay_later_summary_cubit.dart';

/// A DashboardBloc that only holds a given state; events are ignored.
class _StaticDashboardBloc extends Bloc<DashboardEvent, DashboardState>
    implements DashboardBloc {
  final List<DashboardEvent> received = [];

  _StaticDashboardBloc(super.initialState) {
    on<DashboardEvent>((event, _) => received.add(event));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Enough of ManageBudgetUseCase for the ActiveBudgetSelector.
class _FakeManageBudget implements ManageBudgetUseCase {
  @override
  Future<BudgetEntity?> getActive() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Saved settings at their defaults: reminders on.
class _DefaultSettings implements SettingsRepository {
  @override
  Future<AppSettings> loadSettings() async => const AppSettings();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<ManageBudgetUseCase>(_FakeManageBudget());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<_StaticDashboardBloc> pump(
    WidgetTester tester,
    DashboardState state, {
    double width = 540,
    double height = 2000,
  }) async {
    final bloc = _StaticDashboardBloc(state);
    addTearDown(bloc.close);
    final payLater = FakePayLaterSummaryCubit();
    addTearDown(payLater.close);
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DashboardBloc>.value(value: bloc),
            BlocProvider<PayLaterSummaryCubit>.value(value: payLater),
          ],
          child: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  BudgetSummaryEntity summaryFor(String currency) => BudgetSummaryEntity(
    monthlyAmount: 22000,
    remainingBudget: 22000,
    totalSpent: 0,
    todaySpending: 0,
    remainingDays: 22,
    daysPassed: 10,
    dailySafeSpending: 1000,
    budgetUtilization: 0,
    spendingPercentage: 0,
    remainingPercentage: 100,
    averageDailySpending: 0,
    expectedPeriodEndSpending: 0,
    expectedSavings: 0,
    expectedOverspending: 0,
    todayOverspending: 0,
    status: BudgetStatus.underBudget,
    currency: currency,
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
  );

  testWidgets('Home offers notifications once while they are blocked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    getIt.registerSingleton<NotificationPermission>(
      NotificationPermission(
        isAllowed: () async => false,
        request: () async => false,
      ),
    );
    getIt.registerSingleton<LoadSettingsUseCase>(
      LoadSettingsUseCase(repository: _DefaultSettings()),
    );
    final entity = safeToSpend();
    await pump(
      tester,
      DashboardLoaded(
        budgetSummary: summaryFor('INR'),
        recentExpenses: const [],
        insights: const [],
        budgetDailyLimits: [limitFor(entity)],
        activeBudgetId: 'b1',
      ),
    );

    expect(find.text("Get Today's Safe Spending each morning"), findsOneWidget);
  });

  testWidgets('a not-started active budget shows when it starts and what it '
      'sets aside', (tester) async {
    final entity = safeToSpend(
      today: DateTime(2026, 7, 25),
      commitments: [bill('rent', 12000, DateTime(2026, 8, 5), title: 'Rent')],
    );
    await pump(
      tester,
      DashboardNotRunning(activeBudgetId: 'b1', safeToSpend: entity),
    );

    expect(find.byKey(const ValueKey('paused_b1')), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
    expect(find.text('This budget starts 1 Aug'), findsOneWidget);
    expect(
      find.text(
        'Starts 1 Aug. ₹12,000 in bills will be set aside from this budget.',
      ),
      findsOneWidget,
    );
    // The breakdown of what it will set aside, without a forecast.
    expect(find.byType(SafeToSpendBreakdownCard), findsOneWidget);
    expect(find.text('Forecast'), findsNothing);
    expect(find.text('Switch budget'), findsOneWidget);
    // Not the old "blank body" or error view.
    expect(find.text("Couldn't load your dashboard"), findsNothing);
  });

  testWidgets('on a tablet the secondary sections move into a second column', (
    tester,
  ) async {
    final entity = safeToSpend(today: DateTime(2026, 7, 25));
    final state = DashboardNotRunning(
      activeBudgetId: 'b1',
      safeToSpend: entity,
    );

    await pump(tester, state, width: 1000);
    final hero = tester.getRect(find.byKey(const ValueKey('paused_b1')));
    final recent = tester.getRect(find.text('Recent'));
    expect(recent.left, greaterThan(hero.right), reason: 'beside the hero');
    expect(recent.top, lessThan(hero.bottom), reason: 'level with it');

    await pump(tester, state);
    final phoneHero = tester.getRect(find.byKey(const ValueKey('paused_b1')));
    final phoneRecent = tester.getRect(find.text('Recent'));
    expect(phoneRecent.top, greaterThan(phoneHero.bottom), reason: 'below');
  });

  testWidgets('an ended active budget reports its result, no breakdown', (
    tester,
  ) async {
    final entity = safeToSpend(today: DateTime(2026, 9, 5), periodSpent: 20000);
    await pump(
      tester,
      DashboardNotRunning(activeBudgetId: 'b1', safeToSpend: entity),
    );

    // Blueprint: a closed ring with the result in it, then the next period
    // at the daily figure it would start at.
    expect(find.text('Ended 31 Aug'), findsOneWidget);
    expect(find.text('₹2,000 left'), findsOneWidget);
    expect(find.byType(TargetRing), findsOneWidget);
    // 1–30 Sep follows 1–31 Aug: 22,000 ÷ 30 = 733.33…, floored.
    expect(find.text('Start next period at ₹733.33 a day'), findsOneWidget);
    expect(find.text('Switch budget'), findsOneWidget);
    expect(find.text('New budget'), findsOneWidget);
    expect(find.byType(SafeToSpendBreakdownCard), findsNothing);
  });

  testWidgets('a running budget shows the hero, "Why ₹…?" and the '
      'not-linked notice, in that order', (tester) async {
    final entity = safeToSpend(
      unlinked: const UnlinkedCommitmentSummary(count: 1, total: 800),
    );
    await pump(
      tester,
      DashboardLoaded(
        budgetSummary: summaryFor('INR'),
        recentExpenses: const [],
        insights: const [],
        budgetDailyLimits: [limitFor(entity)],
        activeBudgetId: 'b1',
      ),
    );

    final hero = find.byKey(const ValueKey('hero_b1'));
    final free = find.byKey(const Key('whyTarget'));
    final notice = find.text('Bills not linked');
    expect(hero, findsOneWidget);
    expect(free, findsOneWidget);
    expect(notice, findsOneWidget);
    expect(find.text('Link bills'), findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(hero), lessThan(top(free)));
    expect(top(free), lessThan(top(notice)));
    // The budget is the chip at the top, said once (blueprint).
    expect(find.text('Groceries'), findsOneWidget);
    // The full working is one tap away, not always open on the page.
    expect(find.byType(SafeToSpendBreakdownCard), findsNothing);
  });

  testWidgets('"Why ₹…?" opens the working down to today\'s target', (
    tester,
  ) async {
    final entity = safeToSpend(periodSpent: 250, todaySpent: 250);
    await pump(
      tester,
      DashboardLoaded(
        budgetSummary: summaryFor('INR'),
        recentExpenses: const [],
        insights: const [],
        budgetDailyLimits: [limitFor(entity)],
        activeBudgetId: 'b1',
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('whyTarget')));
    await tester.tap(find.byKey(const Key('whyTarget')));
    await tester.pumpAndSettle();

    // The sheet's own rule, under its "Why ₹1,000?" title (blueprint).
    expect(
      find.text(
        "Spend less than the target and tomorrow's rises; spend more and it "
        'falls; spend exactly the target and it stays the same.',
      ),
      findsOneWidget,
    );
    expect(find.byType(SafeToSpendBreakdownCard), findsOneWidget);
    expect(find.text('Spent today, not counting bills'), findsOneWidget);
    expect(find.text('Days left, including today'), findsOneWidget);
    // (21,750 + 250) ÷ 22 days = ₹1,000, the hero's figure.
    expect(
      find.bySemanticsLabel("Today's Safe Spending, ₹1,000"),
      findsOneWidget,
    );
    // Tomorrow if nothing more is spent: 21,750 ÷ 21.
    expect(
      find.text(
        "Spend nothing more today and tomorrow's amount is about ₹1,035.71.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('a running budget without figures never claims it ended', (
    tester,
  ) async {
    final bloc = await pump(
      tester,
      DashboardLoaded(
        budgetSummary: summaryFor('INR'),
        recentExpenses: const [],
        insights: const [],
        activeBudgetId: 'b1',
      ),
    );

    expect(find.byKey(const ValueKey('paused_b1')), findsOneWidget);
    expect(find.textContaining('ended'), findsNothing);
    expect(find.text("Today's Safe Spending isn't available"), findsOneWidget);
    expect(find.byType(SafeToSpendBreakdownCard), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(bloc.received.single, isA<DashboardRefresh>());
  });
  testWidgets('an archived active budget says so instead of offering a retry '
      'that can never succeed (review)', (tester) async {
    await pump(
      tester,
      DashboardLoaded(
        budgetSummary: summaryFor('INR'),
        recentExpenses: const [],
        insights: const [],
        activeBudgetId: 'b1',
        activeBudgetArchived: true,
      ),
    );

    expect(find.byKey(const ValueKey('archived_b1')), findsOneWidget);
    expect(find.text('This budget is archived'), findsOneWidget);
    expect(find.text('Switch budget'), findsOneWidget);
    expect(find.text('Budget details'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text("Today's Safe Spending isn't available"), findsNothing);
  });

  group('first load and the add button (UX-105, UX-073)', () {
    DashboardLoaded loaded() => DashboardLoaded(
      budgetSummary: summaryFor('INR'),
      recentExpenses: const [],
      insights: const [],
      budgetDailyLimits: [limitFor(safeToSpend())],
      activeBudgetId: 'b1',
    );

    testWidgets('the entrance cascade is short and the figure arrives with '
        'the header (review: seven steps delayed when figures settle)', (
      tester,
    ) async {
      await pump(tester, loaded());
      final indices = tester
          .widgetList<FadeSlideIn>(find.byType(FadeSlideIn))
          .map((w) => w.index)
          .toList();
      expect(indices, isNotEmpty);
      expect(indices.reduce(math.max), lessThanOrEqualTo(3));
      final heroEntrance = tester.widget<FadeSlideIn>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('hero_b1')),
              matching: find.byType(FadeSlideIn),
            )
            .first,
      );
      expect(heroEntrance.index, 0);
    });

    // Blueprint: adding moved to the bar's + (AppShell), so Home has no
    // floating button covering its amounts.
    testWidgets('Home has no add button of its own', (tester) async {
      await pump(tester, loaded(), width: 360, height: 640);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('Today (blueprint)', () {
    RecentExpenseEntity expense(String id, DateTime date) =>
        RecentExpenseEntity(
          id: id,
          amount: 180,
          categoryId: 'food',
          categoryName: 'Food',
          categoryIcon: 'restaurant',
          categoryColorHex: '#FF7043',
          note: 'Expense $id',
          date: date,
          createdAt: date,
        );

    DashboardLoaded loaded({
      List<RecentExpenseEntity> recent = const [],
      bool twoBudgets = false,
    }) => DashboardLoaded(
      budgetSummary: summaryFor('INR'),
      recentExpenses: recent,
      insights: const [],
      budgetDailyLimits: [
        limitFor(safeToSpend(periodSpent: 250, todaySpent: 250)),
        if (twoBudgets)
          limitFor(
            safeToSpend(budgetId: 'b2', name: 'Personal', amount: 11000),
          ),
      ],
      activeBudgetId: 'b1',
    );

    testWidgets("the ring, then tomorrow's amount", (tester) async {
      await pump(tester, loaded());
      expect(find.byType(TargetRing), findsOneWidget);
      expect(find.byType(TomorrowCard), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TomorrowCard)).dy,
        greaterThan(tester.getBottomLeft(find.byType(TargetRing)).dy),
      );
    });

    testWidgets('budget chips head the screen, even for one budget', (
      tester,
    ) async {
      await pump(tester, loaded());
      expect(find.byKey(const Key('budget_chip_b1')), findsOneWidget);
      // The date and the day of the period, above them (blueprint).
      expect(find.text('Monday 10 August · day 10 of 31'), findsOneWidget);
      expect(find.textContaining('Good '), findsNothing);

      await pump(tester, loaded(twoBudgets: true));
      expect(find.byKey(const Key('budget_chip_b1')), findsOneWidget);
      expect(find.byKey(const Key('budget_chip_b2')), findsOneWidget);
      // The chips replace the "Other budgets today" list.
      expect(find.text('Other budgets today'), findsNothing);
      // They name the active budget, so the header does not repeat it.
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets("the list under the ring is today's expenses only", (
      tester,
    ) async {
      await pump(
        tester,
        loaded(
          recent: [
            expense('lunch', DateTime(2026, 8, 10, 12, 40)),
            expense('older', DateTime(2026, 8, 9, 19)),
          ],
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Recent'), findsNothing);
      expect(find.text('1 expense · ₹180'), findsOneWidget);
      expect(find.byKey(const ValueKey('recent_lunch')), findsOneWidget);
      expect(find.byKey(const ValueKey('recent_older')), findsNothing);
      // No "See all" here: Activity is a tab away (blueprint).
    });

    testWidgets('nothing today yet says so, with the history one tap away', (
      tester,
    ) async {
      await pump(
        tester,
        loaded(recent: [expense('older', DateTime(2026, 8, 9, 19))]),
      );
      expect(find.text('Nothing spent today yet.'), findsOneWidget);
    });

    testWidgets('"Why ₹…?" sums the target up in one line (blueprint)', (
      tester,
    ) async {
      await pump(tester, loaded());
      // (21,750 free + 250 spent today) ÷ 22 days = 1,000.
      expect(find.text('Why ₹1,000?'), findsOneWidget);
      expect(find.text('₹22,000 ÷ 22 days left'), findsOneWidget);
    });
  });

  testWidgets('no budget: an empty ring and one line (blueprint)', (
    tester,
  ) async {
    await pump(tester, const DashboardEmpty());

    expect(find.text('No target yet'), findsOneWidget);
    expect(find.byType(TargetRing), findsOneWidget);
    expect(find.text('Set a daily target'), findsOneWidget);
    expect(find.text('Create budget'), findsOneWidget);
    expect(find.text('Open budgets'), findsOneWidget);
  });
}
