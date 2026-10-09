@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:monivo/features/dashboard/domain/services/spending_pace_builder.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:monivo/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:monivo/features/dashboard/presentation/widgets/dashboard_header.dart';

import '../features/dashboard/presentation/widgets/safe_to_spend_fixtures.dart';
import 'golden_harness.dart';

/// Holds one state; events are ignored.
class _StaticDashboardBloc extends Bloc<DashboardEvent, DashboardState>
    implements DashboardBloc {
  _StaticDashboardBloc(super.initialState) {
    on<DashboardEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The sample budget on the emulator: ₹60,000 for October, ₹34,897 spent
/// (₹570 today), an ₹1,850 electricity bill set aside, a ₹3,000 savings goal
/// and one bill not linked.
DashboardLoaded _sampleState() {
  final entity = safeToSpend(
    name: 'October Household',
    amount: 60000,
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
    today: DateTime(2026, 10, 8),
    periodSpent: 34897,
    todaySpent: 570,
    savings: 3000,
    commitments: [
      bill('electricity', 1850, DateTime(2026, 10, 12), title: 'Electricity'),
    ],
    unlinked: const UnlinkedCommitmentSummary(count: 1, total: 649),
  );
  final pace = SpendingPaceBuilder.build(
    safeToSpend: entity,
    dailyDiscretionary: {
      DateTime(2026, 10, 1): 3200,
      DateTime(2026, 10, 2): 1900,
      DateTime(2026, 10, 3): 2400,
      DateTime(2026, 10, 4): 15210,
      DateTime(2026, 10, 5): 2967,
      DateTime(2026, 10, 6): 3600,
      DateTime(2026, 10, 7): 5050,
      DateTime(2026, 10, 8): 570,
    },
  );
  final realToday = DateTime.now();
  BillEntity upcoming(
    String id,
    String title,
    double amount,
    int inDays, {
    String? budgetId,
    BillCategory category = BillCategory.electricity,
  }) => BillEntity(
    id: id,
    title: title,
    amount: amount,
    currency: 'INR',
    category: category,
    // Relative to the real day, so "Due in 4 days" is stable.
    dueDate: DateTime(realToday.year, realToday.month, realToday.day + inDays),
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
    budgetId: budgetId,
  );
  RecentExpenseEntity expense(
    String id,
    String note,
    double amount,
    DateTime date, {
    String category = 'Food',
    String icon = 'restaurant',
    String color = '#FF6B6B',
  }) => RecentExpenseEntity(
    id: id,
    amount: amount,
    categoryId: category.toLowerCase(),
    categoryName: category,
    categoryIcon: icon,
    categoryColorHex: color,
    note: note,
    date: date,
    createdAt: date,
  );
  final other = limitFor(
    safeToSpend(
      budgetId: 'personal',
      name: 'Personal',
      amount: 9000,
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      today: DateTime(2026, 10, 8),
      periodSpent: 1620,
      todaySpent: 800,
    ),
  );
  return DashboardLoaded(
    budgetSummary: BudgetSummaryEntity(
      monthlyAmount: 60000,
      remainingBudget: 25103,
      totalSpent: 34897,
      todaySpending: 570,
      remainingDays: 24,
      daysPassed: 8,
      dailySafeSpending: 1069,
      budgetUtilization: 34897 / 60000,
      spendingPercentage: 58,
      remainingPercentage: 42,
      averageDailySpending: 4362,
      expectedPeriodEndSpending: 135000,
      expectedSavings: 0,
      expectedOverspending: 75000,
      todayOverspending: 0,
      status: BudgetStatus.underBudget,
      currency: 'INR',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
    ),
    recentExpenses: [
      expense('lunch', 'Lunch', 390, DateTime(2026, 10, 8, 12, 40)),
      expense('breakfast', 'Breakfast', 180, DateTime(2026, 10, 8, 8, 30)),
      expense(
        'gift',
        'Birthday gift for Ananya',
        2200,
        DateTime(2026, 10, 7, 19, 30),
        category: 'Shopping',
        icon: 'shopping_cart',
        color: '#FECA57',
      ),
    ],
    insights: const [],
    upcomingBills: [
      upcoming('electricity', 'Electricity', 1850, 4, budgetId: 'b1'),
      upcoming(
        'netflix',
        'Netflix',
        649,
        12,
        category: BillCategory.subscription,
      ),
    ],
    budgetDailyLimits: [
      _withUtilization(limitFor(entity), 34897 / 60000),
      other,
    ],
    activeBudgetId: 'b1',
    spendingPace: pace,
  );
}

/// [limit] with the domain's spent ÷ amount ratio, which the shared
/// fixture leaves at 0.
BudgetDailyLimitEntity _withUtilization(
  BudgetDailyLimitEntity limit,
  double utilization,
) => BudgetDailyLimitEntity(
  budgetId: limit.budgetId,
  budgetName: limit.budgetName,
  dailyLimit: limit.dailyLimit,
  spentToday: limit.spentToday,
  remainingToday: limit.remainingToday,
  exceededToday: limit.exceededToday,
  progress: limit.progress,
  isOverLimit: limit.isOverLimit,
  status: limit.status,
  budgetStatus: limit.budgetStatus,
  budgetUtilization: utilization,
  monthlyAmount: limit.monthlyAmount,
  totalSpent: limit.totalSpent,
  remainingBudget: limit.remainingBudget,
  remainingDays: limit.remainingDays,
  weeklyTarget: limit.weeklyTarget,
  weeklySpent: limit.weeklySpent,
  weeklyRemaining: limit.weeklyRemaining,
  weeklyExceeded: limit.weeklyExceeded,
  weeklyProgress: limit.weeklyProgress,
  weeklyStatus: limit.weeklyStatus,
  currency: limit.currency,
  startDate: limit.startDate,
  endDate: limit.endDate,
  safeToSpend: limit.safeToSpend,
);

void main() {
  testWidgets('home', (tester) async {
    DashboardHeader.clock = () => DateTime(2026, 10, 8, 15, 30);
    addTearDown(() => DashboardHeader.clock = DateTime.now);
    final bloc = _StaticDashboardBloc(_sampleState());
    addTearDown(bloc.close);
    await expectGoldenMatrix(
      tester,
      'home',
      BlocProvider<DashboardBloc>.value(
        value: bloc,
        child: const DashboardScreen(),
      ),
      size: const Size(360, 2000),
    );
  }, skip: goldenSkip);

  testWidgets('home tablet', (tester) async {
    DashboardHeader.clock = () => DateTime(2026, 10, 8, 15, 30);
    addTearDown(() => DashboardHeader.clock = DateTime.now);
    final bloc = _StaticDashboardBloc(_sampleState());
    addTearDown(bloc.close);
    // Two columns from 840 dp: today's figure on the left, the rest beside.
    await expectGoldenMatrix(
      tester,
      'home_tablet',
      BlocProvider<DashboardBloc>.value(
        value: bloc,
        child: const DashboardScreen(),
      ),
      size: const Size(1024, 1300),
    );
  }, skip: goldenSkip);

  testWidgets('home without a budget', (tester) async {
    final bloc = _StaticDashboardBloc(const DashboardEmpty());
    addTearDown(bloc.close);
    await expectGoldenMatrix(
      tester,
      'home_empty',
      BlocProvider<DashboardBloc>.value(
        value: bloc,
        child: const DashboardScreen(),
      ),
      size: const Size(360, 780),
    );
  }, skip: goldenSkip);
}
