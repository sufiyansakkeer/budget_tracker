@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bills_list_screen.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_list_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_details_screen.dart';
import 'package:monivo/features/budget/presentation/pages/budget_list_screen.dart';

import '../helpers/bill_ui_fakes.dart';
import '../helpers/safe_to_spend_fakes.dart';
import 'golden_harness.dart';

/// A fixed summary, so the footer never depends on the real date.
class _FixedSummary extends GetBudgetListSummaryUseCase {
  final BudgetListSummaryEntity summary;

  _FixedSummary(this.summary, BudgetRepository repository)
    : super(repository: repository);

  @override
  Future<BudgetResult<BudgetListSummaryEntity>> call() async =>
      BudgetSuccess(summary);
}

class _StatsRepository extends ListBudgetRepository {
  _StatsRepository(super.budgets, super.activeId);

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => budgetId == 'personal'
      ? const MonthlyStatisticsEntity(
          totalSpent: 800,
          expenseCount: 2,
          todaySpending: 240,
        )
      : const MonthlyStatisticsEntity(
          totalSpent: 34897,
          expenseCount: 21,
          todaySpending: 570,
        );
}

BudgetEntity _budget(
  String id,
  String name, {
  required DateTime start,
  required DateTime end,
  double amount = 30000,
  double? remaining,
  String currency = 'INR',
  String? icon,
  String? color,
  bool archived = false,
}) => BudgetEntity(
  id: id,
  name: name,
  monthlyAmount: amount,
  remainingAmount: remaining ?? amount,
  currency: currency,
  startDate: start,
  endDate: end,
  icon: icon,
  color: color,
  isArchived: archived,
  createdAt: start,
  updatedAt: start,
);

void main() {
  // Budgets use a fixed day, so periods and day counts never change. USD
  // stands in for a second currency: the test engine has no Arabic font,
  // so OMR's symbol would draw as boxes.
  final fixedNow = DateTime(2026, 10, 9, 10);
  final household = _budget(
    'household',
    'October Household',
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
    amount: 60000,
    remaining: 25103,
    icon: 'family',
    color: '0xFF009688',
  );
  final budgets = [
    household,
    _budget(
      'personal',
      'Personal',
      start: DateTime(2026, 10, 8),
      end: DateTime(2026, 11, 7),
      amount: 4567,
      remaining: 3767,
      icon: 'personal',
      color: '0xFF9C27B0',
    ),
    _budget(
      'muscat',
      'Muscat trip',
      start: DateTime(2026, 10, 5),
      end: DateTime(2026, 10, 20),
      amount: 300,
      remaining: 120.5,
      currency: 'USD',
      icon: 'travel',
      color: '0xFF2196F3',
    ),
    _budget(
      'diwali',
      'Diwali',
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 15),
      amount: 15000,
      icon: 'home',
      color: '0xFFFF9800',
    ),
    _budget(
      'summer',
      'Summer 2026',
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 8, 31),
      amount: 20000,
      remaining: -1200,
      icon: 'vacation',
      color: '0xFFF44336',
    ),
  ];

  setUp(() async {
    await getIt.reset();
    BudgetListScreen.clock = () => fixedNow;
    BudgetDetailsScreen.clock = () => fixedNow;
    final repository = _StatsRepository(budgets, 'household');
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(repository: repository),
      )
      ..registerSingleton<BudgetRepository>(repository)
      ..registerSingleton<GetBudgetListSummaryUseCase>(
        _FixedSummary(
          const BudgetListSummaryEntity(
            remainingByCurrency: {'INR': 28870, 'USD': 120.5},
            activeBudgetCount: 3,
          ),
          repository,
        ),
      );
  });
  tearDown(() async {
    BudgetListScreen.clock = DateTime.now;
    BudgetDetailsScreen.clock = DateTime.now;
    await getIt.reset();
  });

  testWidgets('budgets list', (tester) async {
    await expectGoldenMatrix(
      tester,
      'budgets_list',
      const BudgetListScreen(),
      size: const Size(360, 1200),
    );
  }, skip: goldenSkip);

  testWidgets('budget details', (tester) async {
    await expectGoldenMatrix(
      tester,
      'budget_details',
      const BudgetDetailsScreen(budgetId: 'personal'),
      size: const Size(360, 900),
    );
  }, skip: goldenSkip);

  testWidgets('bills list', (tester) async {
    // Bills are due relative to the real day ("Due in 3 days"), which is
    // all the list shows, so the image stays the same.
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    BillEntity bill(
      String id,
      String title,
      double amount,
      int dueIn,
      BillCategory category, {
      String currency = 'INR',
      String? budgetId,
      bool paid = false,
      bool recurring = false,
    }) => BillEntity(
      id: id,
      title: title,
      amount: amount,
      currency: currency,
      category: category,
      dueDate: day(dueIn),
      budgetId: budgetId,
      isPaid: paid,
      // A fixed date: the row shows it ("Paid 7 Oct").
      paidDate: paid ? DateTime(2026, 10, 7) : null,
      isRecurring: recurring,
      recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
      reminderEnabled: false,
      createdAt: day(-40),
      updatedAt: day(-40),
    );
    final bills = SafeSpendFakeBillRepository([
      bill(
        'rent',
        'Rent',
        18000,
        -2,
        BillCategory.rent,
        budgetId: 'household',
        recurring: true,
      ),
      bill(
        'visa',
        'Visa fee',
        12.5,
        -1,
        BillCategory.government,
        currency: 'USD',
      ),
      bill(
        'power',
        'Electricity',
        1850,
        3,
        BillCategory.electricity,
        budgetId: 'household',
        recurring: true,
      ),
      bill(
        'netflix',
        'Netflix',
        649,
        11,
        BillCategory.subscription,
        recurring: true,
      ),
      bill('insurance', 'Car insurance', 12400, 40, BillCategory.insurance),
      bill('phone', 'Phone', 499, -5, BillCategory.phone, paid: true),
    ]);
    await expectGoldenMatrix(
      tester,
      'bills_list',
      BlocProvider<BillBloc>(
        create: (_) => buildTestBillBloc(bills),
        child: const BillsListScreen(),
      ),
      size: const Size(360, 1300),
    );
  }, skip: goldenSkip);
}
