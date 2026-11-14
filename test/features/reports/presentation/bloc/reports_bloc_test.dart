import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/reports/domain/entities/report_data.dart';
import 'package:monivo/features/reports/domain/entities/report_failure.dart';
import 'package:monivo/features/reports/domain/entities/report_overview.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/entities/spending_trend.dart';
import 'package:monivo/features/reports/domain/entities/time_analytics.dart';
import 'package:monivo/features/reports/domain/services/report_insight_generator.dart';
import 'package:monivo/features/reports/domain/usecases/get_report_data_usecase.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_event.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGetReportDataUseCase implements GetReportDataUseCase {
  final ReportDataResult? resultToReturn;

  MockGetReportDataUseCase({this.resultToReturn});

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ReportDataResult> call({
    required ReportPeriod period,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (resultToReturn != null) {
      return resultToReturn!;
    }
    throw UnimplementedError();
  }
}

/// Answers each period after its own delay, so a slow load can finish last.
class _SlowFirstReports implements GetReportDataUseCase {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ReportDataResult> call({
    required ReportPeriod period,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (period == ReportPeriod.thisYear) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return ReportSuccess(buildEmptyData(period));
  }
}

/// Counts loads; answers at once.
class _CountingReports implements GetReportDataUseCase {
  int calls = 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ReportDataResult> call({
    required ReportPeriod period,
    ExpenseHistoryFilter filter = const ExpenseHistoryFilter(),
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    calls++;
    return ReportSuccess(buildEmptyData(period));
  }
}

ReportData buildEmptyData(ReportPeriod period) {
  return ReportData(
    range: ReportRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
      period: period,
    ),
    filteredExpenses: const [],
    categories: defaultCategories,
    filter: const ExpenseHistoryFilter(),
    overview: ReportOverview.empty,
    dailySpending: const [],
    spendingBuckets: const [],
    categoryAnalytics: const [],
    timeAnalytics: TimeAnalytics.empty,
    trend: SpendingTrend.empty,
  );
}

ReportData buildData(ReportPeriod period) {
  final now = DateTime(2026, 8, 5);
  final expense = ExpenseEntity(
    id: '1',
    budgetId: 'budget-1',
    amount: 100,
    categoryId: 'food',
    date: now,
    time: now,
    createdAt: now,
    updatedAt: now,
  );
  return ReportData(
    range: ReportRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
      period: period,
    ),
    filteredExpenses: [expense],
    categories: defaultCategories,
    filter: const ExpenseHistoryFilter(),
    overview: const ReportOverview(
      totalSpending: 100,
      totalTransactions: 1,
      averageDailySpending: 3,
      averageTransactionAmount: 100,
      highestExpense: 100,
      lowestExpense: 100,
    ),
    dailySpending: const [],
    spendingBuckets: const [],
    categoryAnalytics: const [],
    timeAnalytics: TimeAnalytics.empty,
    trend: SpendingTrend.empty,
  );
}

void main() {
  const generator = ReportInsightGenerator();

  test('initial state is ReportsState initial', () {
    final bloc = ReportsBloc(
      getReportDataUseCase: MockGetReportDataUseCase(),
      insightGenerator: generator,
    );
    expect(bloc.state.status, ReportsStatus.initial);
    expect(bloc.state.period, ReportPeriod.thisMonth);
    bloc.close();
  });

  test('emits loading then loaded with data on successful load', () async {
    final data = buildData(ReportPeriod.thisMonth);
    final bloc = ReportsBloc(
      getReportDataUseCase: MockGetReportDataUseCase(
        resultToReturn: ReportSuccess(data),
      ),
      insightGenerator: generator,
    );

    final expectedStates = <ReportsState>[];

    final testSubscription = bloc.stream.listen((state) {
      expectedStates.add(state);
    });

    bloc.add(const ReportsLoad());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await testSubscription.cancel();

    expect(expectedStates.first.status, ReportsStatus.loading);
    expect(expectedStates.last.status, ReportsStatus.loaded);
    expect(expectedStates.last.data, data);
    expect(expectedStates.last.isEmpty, false);
    expect(expectedStates.last.insights, isNotNull);
    bloc.close();
  });

  test('emits loading then error on failure', () async {
    final bloc = ReportsBloc(
      getReportDataUseCase: MockGetReportDataUseCase(
        resultToReturn: const ReportError(
          ReportFailure(
            type: ReportErrorType.databaseFailure,
            message: 'DB error',
          ),
        ),
      ),
      insightGenerator: generator,
    );

    final expectedStates = <ReportsState>[];
    final testSubscription = bloc.stream.listen((state) {
      expectedStates.add(state);
    });

    bloc.add(const ReportsLoad());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await testSubscription.cancel();

    expect(expectedStates.first.status, ReportsStatus.loading);
    expect(expectedStates.last.status, ReportsStatus.error);
    expect(expectedStates.last.errorMessage, 'DB error');
    bloc.close();
  });

  test('marks empty state when report has no expenses', () async {
    final bloc = ReportsBloc(
      getReportDataUseCase: MockGetReportDataUseCase(
        resultToReturn: ReportSuccess(buildEmptyData(ReportPeriod.thisMonth)),
      ),
      insightGenerator: generator,
    );

    final expectedStates = <ReportsState>[];
    final testSubscription = bloc.stream.listen((state) {
      expectedStates.add(state);
    });

    bloc.add(const ReportsLoad());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await testSubscription.cancel();

    expect(expectedStates.last.isEmpty, true);
    expect(expectedStates.last.data!.isEmpty, true);
    bloc.close();
  });

  test('period change reloads with the new period', () async {
    final bloc = ReportsBloc(
      getReportDataUseCase: MockGetReportDataUseCase(
        resultToReturn: ReportSuccess(buildData(ReportPeriod.lastMonth)),
      ),
      insightGenerator: generator,
    );

    final expectedStates = <ReportsState>[];
    final testSubscription = bloc.stream.listen((state) {
      expectedStates.add(state);
    });

    bloc.add(const ReportsLoad());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const ReportsPeriodChanged(ReportPeriod.lastMonth));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await testSubscription.cancel();

    expect(expectedStates.last.period, ReportPeriod.lastMonth);
    expect(expectedStates.last.status, ReportsStatus.loaded);
    bloc.close();
  });

  test('filter change reloads with the new filter', () async {
    final bloc = ReportsBloc(
      getReportDataUseCase: MockGetReportDataUseCase(
        resultToReturn: ReportSuccess(buildData(ReportPeriod.thisMonth)),
      ),
      insightGenerator: generator,
    );

    final expectedStates = <ReportsState>[];
    final testSubscription = bloc.stream.listen((state) {
      expectedStates.add(state);
    });

    bloc.add(const ReportsLoad());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(
      const ReportsFilterChanged(ExpenseHistoryFilter(categoryId: 'food')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await testSubscription.cancel();

    expect(expectedStates.last.filter.categoryId, 'food');
    expect(expectedStates.last.status, ReportsStatus.loaded);
    bloc.close();
  });

  test('a slow period that finishes last does not replace the one chosen '
      'after it', () async {
    final bloc = ReportsBloc(
      getReportDataUseCase: _SlowFirstReports(),
      insightGenerator: const ReportInsightGenerator(),
    );
    addTearDown(bloc.close);

    bloc.add(const ReportsPeriodChanged(ReportPeriod.thisYear));
    bloc.add(const ReportsPeriodChanged(ReportPeriod.thisWeek));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(bloc.state.period, ReportPeriod.thisWeek);
    expect(bloc.state.data?.range.period, ReportPeriod.thisWeek);
  });

  test('UX-065: buses notified together (an import) reload the report '
      'once', () async {
    final reports = _CountingReports();
    final bloc = ReportsBloc(
      getReportDataUseCase: reports,
      insightGenerator: const ReportInsightGenerator(),
    );
    addTearDown(bloc.close);
    bloc.add(const ReportsLoad());
    await pumpEventQueue();
    reports.calls = 0;

    RefreshBuses.budgets.notifyChanged();
    RefreshBuses.expenses.notifyChanged();
    await pumpEventQueue();

    expect(reports.calls, 1);
  });

  test('UX-048: "This Budget" then a quick "This Month" ends on This Month, '
      'not on the budget\'s custom range', () async {
    final bloc = ReportsBloc(
      getReportDataUseCase: _CountingReports(),
      insightGenerator: const ReportInsightGenerator(),
      budgetRepository: _SlowBudgets(),
      clock: () => DateTime(2026, 8, 10),
    );
    addTearDown(bloc.close);

    bloc.add(const ReportsBudgetPeriodSelected());
    bloc.add(const ReportsPeriodChanged(ReportPeriod.thisMonth));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(bloc.state.followsBudget, isFalse);
    expect(bloc.state.period, ReportPeriod.thisMonth);
    expect(bloc.state.data?.range.period, ReportPeriod.thisMonth);
  });
}

/// An active budget that takes a while to read.
class _SlowBudgets implements BudgetRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<BudgetEntity?> getActiveBudget() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return BudgetEntity(
      id: 'aug',
      name: 'August',
      monthlyAmount: 1000,
      remainingAmount: 1000,
      currency: 'USD',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
  }
}
