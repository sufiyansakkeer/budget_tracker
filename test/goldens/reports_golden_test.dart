@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/reports/data/repository/reports_repository_impl.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';
import 'package:monivo/features/reports/domain/services/report_insight_generator.dart';
import 'package:monivo/features/reports/domain/usecases/get_report_data_usecase.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_bloc.dart';
import 'package:monivo/features/reports/presentation/bloc/reports_event.dart';
import 'package:monivo/features/reports/presentation/pages/reports_screen.dart';

import '../features/expenses/presentation/expense_test_fakes.dart';
import '../helpers/bill_ui_fakes.dart';
import 'golden_harness.dart';

void main() {
  // Everything is on fixed dates, read through the bloc's clock, so the
  // image never changes with the calendar or the time zone.
  final today = DateTime(2026, 10, 9, 10);
  final budget = BudgetEntity(
    id: 'household',
    name: 'October Household',
    monthlyAmount: 60000,
    remainingAmount: 60000,
    currency: 'INR',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 31),
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  ExpenseEntity spent(
    String id,
    double amount,
    String category,
    int day, {
    int month = 10,
    String? note,
  }) {
    final at = DateTime(2026, month, day, 12);
    return ExpenseEntity(
      id: id,
      budgetId: budget.id,
      amount: amount,
      categoryId: category,
      note: note,
      date: DateTime(2026, month, day),
      time: at,
      createdAt: at,
      updatedAt: at,
    );
  }

  late MemoryExpenseRepository expenses;
  late ListBudgetRepository budgets;

  setUp(() async {
    await getIt.reset();
    expenses = MemoryExpenseRepository();
    budgets = ListBudgetRepository([budget], budget.id);
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(repository: budgets),
    );
    for (final e in [
      spent('1', 1850, 'bills', 1),
      spent('2', 2400, 'grocery', 2),
      spent('3', 650, 'food', 2),
      spent('4', 4200, 'shopping', 3),
      spent('5', 980, 'fuel', 4),
      spent('6', 1500, 'food', 4),
      spent('7', 300, 'travel', 5),
      spent('8', 2967, 'grocery', 5),
      spent('9', 3600, 'entertainment', 6),
      spent('10', 5050, 'shopping', 7),
      spent('11', 390, 'food', 8),
      spent('12', 180, 'food', 8),
      spent('13', 800, 'food', 9),
      spent('p1', 6000, 'grocery', 25, month: 9),
      spent('p2', 9000, 'shopping', 28, month: 9),
    ]) {
      expenses.store[e.id] = e;
    }
  });
  tearDown(() => getIt.reset());

  testWidgets('reports', (tester) async {
    final reports = ReportsBloc(
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
      clock: () => today,
    );
    addTearDown(reports.close);
    reports.add(const ReportsBudgetPeriodSelected());
    await expectGoldenMatrix(
      tester,
      'reports',
      BlocProvider<ReportsBloc>.value(
        value: reports,
        child: const ReportsScreen(),
      ),
      size: const Size(360, 2600),
    );
  }, skip: goldenSkip);
}
