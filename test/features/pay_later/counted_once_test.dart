import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/bills/data/datasource/bill_local_datasource_impl.dart';
import 'package:monivo/features/bills/data/repository/bill_repository_impl.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/data/datasource/dashboard_local_datasource_impl.dart';
import 'package:monivo/features/dashboard/data/repository/dashboard_repository_impl.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_purchase_usecase.dart';
import 'package:monivo/features/reports/data/repository/reports_repository_impl.dart';
import 'package:monivo/features/reports/domain/entities/report_data.dart';
import 'package:monivo/features/reports/domain/entities/report_failure.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';
import 'package:monivo/features/reports/domain/usecases/get_report_data_usecase.dart';

import '../../helpers/in_memory_database.dart';
import '../../helpers/pay_later_fixtures.dart';

/// Spec §6: a tab purchase is an ordinary expense to every existing figure,
/// and payments are invisible to all of them. Real repositories, real
/// calculators, one in-memory database.
void main() {
  // Mid-period, after the purchase date: every figure below is "today".
  final today = DateTime(2026, 11, 5);

  late AppDatabase db;
  late BudgetRepositoryImpl budgets;
  late ExpenseRepositoryImpl expenses;
  late PayLaterRepositoryImpl payLater;
  late ReconcileTabUseCase reconcile;
  late TabPurchaseUseCase tabPurchases;
  late GetSafeToSpendUseCase safeToSpend;
  late GetReportDataUseCase reportData;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await createInMemoryDatabase();
    budgets = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: db,
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
      calculationService: BudgetCalculationService(),
    );
    expenses = ExpenseRepositoryImpl(
      localDataSource: ExpenseLocalDataSourceImpl(database: db),
      budgetRepository: budgets,
    );
    payLater = PayLaterRepositoryImpl(
      localDataSource: PayLaterLocalDataSourceImpl(database: db),
    );
    reconcile = ReconcileTabUseCase(repository: payLater);
    tabPurchases = TabPurchaseUseCase(
      expenseRepository: expenses,
      budgetRepository: budgets,
      payLaterRepository: payLater,
      reconcileTab: reconcile,
    );
    safeToSpend = GetSafeToSpendUseCase(
      budgetRepository: budgets,
      billRepository: BillRepositoryImpl(
        localDataSource: BillLocalDataSourceImpl(database: db),
      ),
      dashboardRepository: DashboardRepositoryImpl(
        localDataSource: DashboardLocalDataSourceImpl(database: db),
      ),
      calculator: SafeToSpendCalculator(BudgetCalculationService()),
      clock: () => today,
    );
    reportData = GetReportDataUseCase(
      repository: ReportsRepositoryImpl(
        getExpensesUseCase: GetExpensesUseCase(repository: expenses),
        getCategoriesUseCase: GetCategoriesUseCase(repository: expenses),
        filterExpensesUseCase: const FilterExpensesUseCase(),
        budgetRepository: budgets,
      ),
      analyticsService: AnalyticsService(clock: () => today),
    );

    await seedPayLaterBudget(db); // b1: 100 OMR, 1–30 Nov
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'b2',
            name: 'b2',
            monthlyAmount: 100,
            remainingAmount: 100,
            currency: 'OMR',
            startDate: DateTime(2026, 11, 1),
            endDate: DateTime(2026, 11, 30),
          ),
        );
    await budgets.setActiveBudgetId('b1');
    await payLater.createTab(payLaterTab('t1'));
  });

  tearDown(() => db.close());

  Future<double> remaining(String budgetId) async =>
      (await budgets.getBudgetById(budgetId))!.remainingAmount;

  Future<SafeToSpendEntity> safeFor(String budgetId) async {
    final result = await safeToSpend(budgetId: budgetId, referenceDate: today);
    return (result as BudgetSuccess<SafeToSpendEntity>).data;
  }

  Future<ReportData> report() async {
    final result = await reportData(
      period: ReportPeriod.thisMonth,
      referenceDate: today,
    );
    return (result as ReportSuccess<ReportData>).data;
  }

  Future<void> buyOnTab(ExpenseEntity expense) async {
    final result = await tabPurchases.create(expense, tabId: 't1');
    expect(result, isA<ExpenseSuccess<ExpenseEntity>>());
  }

  Future<void> inTabTransaction(Future<void> Function() write) =>
      payLater.transaction(() async {
        await write();
        await reconcile('t1');
      });

  TabPayment payment(double amount) => TabPayment(
    id: 'p1',
    tabId: 't1',
    amount: amount,
    paidDate: DateTime(2026, 11, 3),
    createdAt: payLaterStamp,
    updatedAt: payLaterStamp,
  );

  test(
    'a 10 tab purchase leaves remaining 90, exactly like a plain expense',
    () async {
      await buyOnTab(payLaterExpense('onTab', amount: 10));
      await expenses.createExpense(
        payLaterExpense('plain', amount: 10).copyWith(budgetId: 'b2'),
      );

      expect(await remaining('b1'), 90);
      expect(await remaining('b2'), 90);

      final onTab = await safeFor('b1');
      final plain = await safeFor('b2');
      expect(onTab.dailySafeToSpend, plain.dailySafeToSpend);
      expect(onTab.periodSpent, plain.periodSpent);
      expect(onTab.availableBalance, plain.availableBalance);
    },
  );

  test('recording, editing and deleting a payment leaves remaining, '
      'safe-to-spend and report totals unchanged', () async {
    await buyOnTab(payLaterExpense('e1', amount: 10));
    final remainingBefore = await remaining('b1');
    final safeBefore = await safeFor('b1');
    final reportBefore = await report();
    expect(reportBefore.overview.totalSpending, 10);
    expect(reportBefore.overview.totalTransactions, 1);

    Future<void> expectUnchanged(String after) async {
      expect(await remaining('b1'), remainingBefore, reason: after);
      expect(await safeFor('b1'), safeBefore, reason: after);
      expect(
        (await safeFor('b1')).dailySafeToSpend,
        safeBefore.dailySafeToSpend,
        reason: after,
      );
      final reportAfter = await report();
      expect(reportAfter.overview, reportBefore.overview, reason: after);
      expect(reportAfter, reportBefore, reason: after);
    }

    await inTabTransaction(() => payLater.createPayment(payment(6)));
    expect(await payLater.allocationsOf('t1'), hasLength(1));
    await expectUnchanged('payment recorded');

    await inTabTransaction(() => payLater.updatePayment(payment(10)));
    expect((await payLater.allocationsOf('t1')).single.amount, 10);
    await expectUnchanged('payment edited');

    await inTabTransaction(() => payLater.deletePayment('p1'));
    expect(await payLater.allocationsOf('t1'), isEmpty);
    await expectUnchanged('payment deleted');
  });

  test('the tab purchase appears once in getExpenses', () async {
    await buyOnTab(payLaterExpense('e1', amount: 10));
    await inTabTransaction(() => payLater.createPayment(payment(10)));

    final all = await expenses.getExpenses();
    final inBudget = await expenses.getExpenses(budgetId: 'b1');

    expect(all.where((e) => e.id == 'e1'), hasLength(1));
    expect(all, hasLength(1));
    expect(inBudget.map((e) => e.id), ['e1']);
  });
}
