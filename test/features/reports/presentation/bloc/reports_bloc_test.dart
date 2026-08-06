import 'package:budget_tracker/features/expenses/domain/entities/expense_category.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_entity.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:budget_tracker/features/reports/domain/entities/report_data.dart';
import 'package:budget_tracker/features/reports/domain/entities/report_failure.dart';
import 'package:budget_tracker/features/reports/domain/entities/report_overview.dart';
import 'package:budget_tracker/features/reports/domain/entities/report_period.dart';
import 'package:budget_tracker/features/reports/domain/entities/spending_trend.dart';
import 'package:budget_tracker/features/reports/domain/entities/time_analytics.dart';
import 'package:budget_tracker/features/reports/domain/services/report_insight_generator.dart';
import 'package:budget_tracker/features/reports/domain/usecases/get_report_data_usecase.dart';
import 'package:budget_tracker/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:budget_tracker/features/reports/presentation/bloc/reports_event.dart';
import 'package:budget_tracker/features/reports/presentation/bloc/reports_state.dart';
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
    categorySlices: const [],
    categoryAnalytics: const [],
    timeAnalytics: TimeAnalytics.empty,
    trend: SpendingTrend.empty,
  );
}

ReportData buildData(ReportPeriod period) {
  final now = DateTime(2026, 8, 5);
  final expense = ExpenseEntity(
    id: '1',
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
    categorySlices: const [],
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
}
