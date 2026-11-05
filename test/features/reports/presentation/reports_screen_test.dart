import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/domain/entities/smart_insight_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/reports/data/repository/reports_repository_impl.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/entities/monthly_spending_bucket.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';
import 'package:monivo/features/reports/domain/services/report_insight_generator.dart';
import 'package:monivo/features/reports/domain/usecases/get_report_data_usecase.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_event.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_state.dart';
import 'package:monivo/features/reports/presentation/pages/reports_screen.dart';
import 'package:monivo/features/reports/presentation/widgets/bar_chart_card.dart';
import 'package:monivo/features/reports/presentation/widgets/report_total.dart';

import '../../../helpers/bill_ui_fakes.dart';
import '../../expenses/presentation/expense_test_fakes.dart';
import '../../../helpers/pay_later_fakes.dart';

/// Expenses whose reads can be made to fail.
class _FlakyExpenses extends MemoryExpenseRepository {
  bool failReads = false;

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    DateTime? from,
    DateTime? to,
  }) {
    if (failReads) throw Exception('disk busy');
    return super.getExpenses(budgetId: budgetId, from: from, to: to);
  }
}

final _today = DateTime(2026, 10, 9, 10);

BudgetEntity _household() => BudgetEntity(
  id: 'household',
  name: 'Household',
  monthlyAmount: 60000,
  remainingAmount: 60000,
  currency: 'INR',
  startDate: DateTime(2026, 10, 1),
  endDate: DateTime(2026, 10, 31),
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

ExpenseEntity _spent(
  String id,
  double amount,
  String categoryId,
  DateTime day, {
  String? note,
}) {
  final at = DateTime(day.year, day.month, day.day, 12);
  return ExpenseEntity(
    id: id,
    budgetId: 'household',
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: DateTime(day.year, day.month, day.day),
    time: at,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  late _FlakyExpenses expenses;
  late ListBudgetRepository budgets;

  setUp(() async {
    await getIt.reset();
    expenses = _FlakyExpenses();
    budgets = ListBudgetRepository([_household()], 'household');
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(
        repository: budgets,
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
    // This budget (1–9 Oct): 9,000 across categories; the 9 days before
    // (22–30 Sep): 6,000, so this period is 50% more.
    for (final e in [
      _spent('a', 4000, 'food', DateTime(2026, 10, 3), note: 'Groceries run'),
      _spent('b', 2500, 'fuel', DateTime(2026, 10, 4)),
      _spent('c', 1500, 'food', DateTime(2026, 10, 6), note: 'Dinner out'),
      _spent('d', 1000, 'travel', DateTime(2026, 10, 8)),
      _spent('p1', 3000, 'food', DateTime(2026, 9, 25)),
      _spent('p2', 3000, 'fuel', DateTime(2026, 9, 28)),
    ]) {
      expenses.store[e.id] = e;
    }
  });
  tearDown(() => getIt.reset());

  ReportsBloc bloc() => ReportsBloc(
    getReportDataUseCase: GetReportDataUseCase(
      repository: ReportsRepositoryImpl(
        getExpensesUseCase: GetExpensesUseCase(repository: expenses),
        getCategoriesUseCase: GetCategoriesUseCase(repository: expenses),
        filterExpensesUseCase: const FilterExpensesUseCase(),
        budgetRepository: budgets,
      ),
      analyticsService: const AnalyticsService(),
    ),
    insightGenerator: const ReportInsightGenerator(),
    budgetRepository: budgets,
    clock: () => _today,
  );

  /// Pumps Reports with "This Budget" chosen, or [period] when given.
  Future<ReportsBloc> pump(
    WidgetTester tester, {
    Size size = const Size(400, 2200),
    double textScale = 1,
    ReportPeriod? period,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reports = bloc();
    addTearDown(reports.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: BlocProvider<ReportsBloc>.value(
            value: reports,
            child: const ReportsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chip = find.byKey(
      Key(period == null ? 'period_thisBudget' : 'period_${period.name}'),
    );
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    return reports;
  }

  group('This Budget', () {
    test('reports the active budget from its start to today', () async {
      final reports = bloc();
      addTearDown(reports.close);
      reports.add(const ReportsBudgetPeriodSelected());
      final state = await reports.stream.firstWhere(
        (s) => s.status == ReportsStatus.loaded,
      );

      expect(state.followsBudget, isTrue);
      expect(state.budget?.id, 'household');
      expect(state.data!.range.start, DateTime(2026, 10, 1));
      expect(state.data!.range.end, DateTime(2026, 10, 9));
      expect(state.data!.overview.totalSpending, 9000);
    });

    test('choosing another period stops following the budget', () async {
      final reports = bloc();
      addTearDown(reports.close);
      reports.add(const ReportsBudgetPeriodSelected());
      await reports.stream.firstWhere((s) => s.status == ReportsStatus.loaded);
      reports.add(const ReportsPeriodChanged(ReportPeriod.lastWeek));
      final state = await reports.stream.firstWhere(
        (s) => s.status == ReportsStatus.loaded,
      );
      expect(state.followsBudget, isFalse);
      expect(state.budget, isNull);
      expect(state.period, ReportPeriod.lastWeek);
    });

    test('a refresh follows a switch to another budget', () async {
      final reports = bloc();
      addTearDown(reports.close);
      reports.add(const ReportsBudgetPeriodSelected());
      await reports.stream.firstWhere((s) => s.status == ReportsStatus.loaded);

      budgets.budgets.add(
        _household().copyWith(
          id: 'trip',
          name: 'Trip',
          startDate: DateTime(2026, 10, 5),
          endDate: DateTime(2026, 10, 7),
        ),
      );
      budgets.activeId = 'trip';
      reports.add(const ReportsRefresh());
      final state = await reports.stream.firstWhere(
        (s) => s.status == ReportsStatus.loaded && s.budget?.id == 'trip',
      );
      // An ended budget runs to its own end, not to today.
      expect(state.data!.range.start, DateTime(2026, 10, 5));
      expect(state.data!.range.end, DateTime(2026, 10, 7));
    });

    test('without an active budget it says so', () async {
      budgets.activeId = null;
      final reports = bloc();
      addTearDown(reports.close);
      reports.add(const ReportsBudgetPeriodSelected());
      final state = await reports.stream.firstWhere(
        (s) => s.status == ReportsStatus.error,
      );
      expect(state.errorMessage, ReportsBloc.noBudgetMessage);
      expect(state.followsBudget, isFalse);
    });

    test('a budget that cannot be read is not reported as missing', () async {
      budgets.throwOnRead = true;
      final reports = bloc();
      addTearDown(reports.close);
      reports.add(const ReportsBudgetPeriodSelected());
      final state = await reports.stream.firstWhere(
        (s) => s.status == ReportsStatus.error,
      );
      expect(state.errorMessage, ReportsBloc.budgetUnreadableMessage);
      // Still on "This Budget", so Retry reads the budget again.
      expect(state.followsBudget, isTrue);
    });
  });

  testWidgets('leads with the total and how it compares', (tester) async {
    await pump(tester);

    expect(find.text('Spent'), findsOneWidget);
    expect(find.text(AppMoney.format(9000, currency: 'INR')), findsWidgets);
    expect(
      find.text('50% more than the 9 days before (22 – 30 Sep)'),
      findsOneWidget,
    );
    expect(find.text('Daily average'), findsOneWidget);
    // UX-027: the average says what it divides by.
    expect(find.text('9 days, incl. today'), findsOneWidget);
    expect(find.text(AppMoney.format(1000, currency: 'INR')), findsWidgets);
  });

  group('calendar periods say they cover the active budget only (UX-017)', () {
    testWidgets('the scope is stated under the range', (tester) async {
      await pump(tester, period: ReportPeriod.lastWeek);
      expect(find.text('Only expenses in Household'), findsOneWidget);
      // 28 Sep – 4 Oct, all past.
      expect(find.text('7 days'), findsOneWidget);
    });

    testWidgets('"This Budget" needs no scope line', (tester) async {
      await pump(tester);
      expect(find.text('Only expenses in Household'), findsNothing);
    });

    testWidgets('a period before the budget offers to switch budget, not to '
        'add an expense', (tester) async {
      expenses.store
        ..remove('p1')
        ..remove('p2');
      await pump(tester, period: ReportPeriod.lastMonth);

      expect(
        find.text(
          'Your active budget starts 1 Oct. Switch budget to see earlier '
          'spending.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add expense'), findsNothing);

      await tester.tap(find.text('Switch budget'));
      await tester.pumpAndSettle();
      expect(
        find.text('Home, Expenses and Reports follow the active budget.'),
        findsOneWidget,
      );
    });

    testWidgets('a period after the budget ended says when it ended', (
      tester,
    ) async {
      budgets.budgets[0] = _household().copyWith(
        endDate: DateTime(2026, 10, 4),
      );
      expenses.store
        ..remove('c')
        ..remove('d');
      await pump(tester, period: ReportPeriod.thisWeek);

      expect(
        find.text(
          'Your active budget ended 4 Oct. Switch budget to see later '
          'spending.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add expense'), findsNothing);
    });

    testWidgets('an empty period inside the budget still offers to add an '
        'expense', (tester) async {
      expenses.store.clear();
      await pump(tester, period: ReportPeriod.thisWeek);
      expect(find.text('No expenses in this period'), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
    });
  });

  testWidgets('shows the plan against what was spent, with today ticked', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Planned vs actual'), findsOneWidget);
    expect(find.text('of ₹60,000 planned'), findsOneWidget);
    expect(
      find.text('15% used · Day 9 of 31 · 23 days left, incl.\u00A0today'),
      findsOneWidget,
    );
  });

  testWidgets('ranks categories and lists one when tapped', (tester) async {
    await pump(tester);

    double y(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('rank_$id'))).dy;
    expect(y('food'), lessThan(y('fuel')));
    expect(y('fuel'), lessThan(y('travel')));

    await tester.tap(find.byKey(const ValueKey('rank_food')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries run'), findsOneWidget);
    expect(find.text('Dinner out'), findsOneWidget);
    expect(find.textContaining('2 expenses'), findsWidgets);
  });

  testWidgets('dates are chosen once: the filter sheet has none', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('reportsFilter')));
    await tester.pumpAndSettle();
    expect(find.text('Date range'), findsNothing);
    expect(find.text('Amount range'), findsOneWidget);
  });

  testWidgets('export lives in the menu', (tester) async {
    await pump(tester);
    expect(find.text('Share this report as a file'), findsNothing);
    await tester.tap(find.byKey(const Key('reportsMenu')));
    await tester.pumpAndSettle();
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the last report with a retry '
      '(review: an error replaced the whole screen)', (tester) async {
    final reports = await pump(tester);

    expenses.failReads = true;
    reports.add(const ReportsRefresh());
    await tester.pumpAndSettle();
    expect(find.text("Couldn't update the report"), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.textContaining('disk busy'), findsNothing);

    expenses.failReads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't update the report"), findsNothing);
  });

  testWidgets('insights repeat nothing the screen already shows', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('accounts for'), findsNothing);
    expect(
      find.textContaining('than in the same number of days'),
      findsNothing,
    );
    expect(find.textContaining('You spent the most on'), findsNothing);
  });

  testWidgets('the weekly rhythm names the heaviest day', (tester) async {
    await pump(tester);
    // 3 Oct 2026 is a Saturday (4,000, the largest).
    expect(find.text('Weekly rhythm'), findsOneWidget);
    // UX-050: a total over this period, not a habit.
    expect(
      find.textContaining('Most spent on Saturdays in this period'),
      findsOneWidget,
    );
  });

  group('UX-050: the weekend share needs whole weeks', () {
    testWidgets('9 days: some weekdays count twice, so no share', (
      tester,
    ) async {
      await pump(tester);
      expect(find.textContaining('weekends are'), findsNothing);
    });

    testWidgets('a whole week: the share is shown', (tester) async {
      await pump(tester, period: ReportPeriod.lastWeek);
      // 28 Sep – 4 Oct: 3,000 on Monday, 6,500 on the weekend.
      expect(
        find.textContaining('weekends are 68% of spending'),
        findsOneWidget,
      );
    });

    test('the weekend insight is dropped too', () {
      const weekend = SmartInsight(
        id: 'weekend_spending',
        message: 'Weekends account for a large share.',
        type: InsightType.warning,
      );
      expect(
        ReportInsightFilter.visible(
          [weekend],
          rhythmShown: false,
          wholeWeeks: false,
        ),
        isEmpty,
      );
      expect(
        ReportInsightFilter.visible(
          [weekend],
          rhythmShown: false,
          wholeWeeks: true,
        ),
        [weekend],
      );
    });
  });

  group('UX-053: an active filter is visible', () {
    Future<ReportsBloc> filtered(WidgetTester tester) async {
      final reports = await pump(tester);
      reports.add(
        const ReportsFilterChanged(ExpenseHistoryFilter(categoryId: 'food')),
      );
      await tester.pumpAndSettle();
      return reports;
    }

    testWidgets('as removable chips under the range', (tester) async {
      final reports = await filtered(tester);
      expect(find.byKey(const ValueKey('activeFilter_Food')), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Food filter'));
      await tester.pumpAndSettle();
      expect(reports.state.filter.isActive, isFalse);
      expect(find.byKey(const ValueKey('activeFilter_Food')), findsNothing);
    });

    testWidgets('the badge is not an error red', (tester) async {
      await filtered(tester);
      final context = tester.element(find.byType(ReportsScreen));
      expect(
        tester.widget<Badge>(find.byType(Badge)).backgroundColor,
        Theme.of(context).colorScheme.primary,
      );
    });

    testWidgets('the hidden plan says why', (tester) async {
      await filtered(tester);
      expect(find.text('Planned vs actual'), findsNothing);
      expect(
        find.text(
          'Planned vs actual is hidden while a filter is on: the plan '
          'covers every expense.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('UX-061: Reports meets tap target and labelling guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, size: const Size(400, 900));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      find.bySemanticsLabel('Report period 1 Oct – 9 Oct 2026, 9 days. Change'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('UX-054: at 200% text the three figures stack, so no label '
      'breaks mid-word', (tester) async {
    await pump(tester, size: const Size(360, 4000), textScale: 2);
    Finder inTotal(String text) => find.descendant(
      of: find.byType(ReportTotal),
      matching: find.text(text),
    );
    final average = tester.getTopLeft(inTotal('Daily average'));
    final count = tester.getTopLeft(inTotal('Expenses'));
    expect(count.dy, greaterThan(average.dy));
    expect(
      tester
          .renderObject<RenderParagraph>(inTotal('Expenses'))
          .didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('buckets a month apart read as months (review: a long custom '
      'range drew months labelled "week")', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: BarChartCard(
            currency: 'INR',
            buckets: [
              SpendingBucket(
                label: 'Jul',
                amount: 100,
                startDate: DateTime(2026, 7, 1),
              ),
              SpendingBucket(
                label: 'Aug',
                amount: 200,
                startDate: DateTime(2026, 8, 1),
              ),
              SpendingBucket(
                label: 'Sep',
                amount: 150,
                startDate: DateTime(2026, 9, 1),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Spending by month'), findsOneWidget);
    expect(find.text('Spending by week'), findsNothing);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      await pump(tester, size: Size(width, 4000), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
