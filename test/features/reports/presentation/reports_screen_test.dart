import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
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

import '../../../helpers/bill_ui_fakes.dart';
import '../../expenses/presentation/expense_test_fakes.dart';

/// Expenses whose reads can be made to fail.
class _FlakyExpenses extends MemoryExpenseRepository {
  bool failReads = false;

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
    DateTime? from,
    DateTime? to,
  }) {
    if (failReads) throw Exception('disk busy');
    return super.getExpenses(
      budgetId: budgetId,
      month: month,
      year: year,
      from: from,
      to: to,
    );
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
      ManageBudgetUseCase(repository: budgets),
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

  /// Pumps Reports with "This Budget" chosen.
  Future<ReportsBloc> pump(
    WidgetTester tester, {
    Size size = const Size(400, 2200),
    double textScale = 1,
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
    await tester.tap(find.byKey(const Key('period_thisBudget')));
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
    expect(find.text(AppMoney.format(1000, currency: 'INR')), findsWidgets);
  });

  testWidgets('shows the plan against what was spent, with today ticked', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Planned vs actual'), findsOneWidget);
    expect(find.text('of ₹60,000 planned'), findsOneWidget);
    expect(find.text('15% used · Day 9 of 31 · 23 days left'), findsOneWidget);
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
    expect(find.textContaining('Most on Saturdays'), findsOneWidget);
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
