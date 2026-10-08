import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:monivo/features/dashboard/presentation/widgets/free_to_spend_summary.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_breakdown_card.dart';

import '../widgets/safe_to_spend_fixtures.dart';

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
    DashboardState state,
  ) async {
    final bloc = _StaticDashboardBloc(state);
    addTearDown(bloc.close);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<DashboardBloc>.value(
          value: bloc,
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

  testWidgets('an ended active budget reports its result, no breakdown', (
    tester,
  ) async {
    final entity = safeToSpend(today: DateTime(2026, 9, 5), periodSpent: 20000);
    await pump(
      tester,
      DashboardNotRunning(activeBudgetId: 'b1', safeToSpend: entity),
    );

    expect(find.text('Ended'), findsOneWidget);
    expect(find.text('This budget ended 31 Aug'), findsOneWidget);
    expect(find.text('Ended 31 Aug with ₹2,000 left.'), findsOneWidget);
    expect(find.byType(SafeToSpendBreakdownCard), findsNothing);
  });

  testWidgets('a running budget shows the hero, what is free to spend and '
      'the not-linked notice, in that order', (tester) async {
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
    final free = find.byType(FreeToSpendSummary);
    final notice = find.text('Bills not linked');
    expect(hero, findsOneWidget);
    expect(free, findsOneWidget);
    expect(notice, findsOneWidget);
    expect(find.text('Link bills'), findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(hero), lessThan(top(free)));
    expect(top(free), lessThan(top(notice)));
    // The budget is the screen title, said once.
    expect(find.text('Groceries'), findsOneWidget);
    // The full working is one tap away, not always open on the page.
    expect(find.byType(SafeToSpendBreakdownCard), findsNothing);
  });

  testWidgets('"Free to spend" opens the working down to today\'s amount', (
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

    await tester.tap(find.byType(FreeToSpendSummary));
    await tester.pumpAndSettle();

    expect(find.text("How today's amount is worked out"), findsOneWidget);
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
}
