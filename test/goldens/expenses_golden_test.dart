@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';
import 'package:monivo/features/expenses/presentation/history/pages/expense_history_screen.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_details_screen.dart';
import 'package:monivo/features/expenses/presentation/quick_add/quick_add_sheet.dart';

import '../features/expenses/presentation/expense_test_fakes.dart';
import 'golden_harness.dart';

/// Holds one state; events are ignored.
class _StaticHistoryBloc extends Bloc<ExpenseHistoryEvent, ExpenseHistoryState>
    implements ExpenseHistoryBloc {
  _StaticHistoryBloc(super.initialState) {
    on<ExpenseHistoryEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticExpenseBloc extends Bloc<ExpenseEvent, ExpenseState>
    implements ExpenseBloc {
  _StaticExpenseBloc(super.initialState) {
    on<ExpenseEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Today and yesterday only, relative to the real clock, so the group
  // labels ("Today", "Yesterday") never change.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final budget = testBudget(
    start: DateTime(today.year, today.month, today.day - 7),
    end: DateTime(today.year, today.month, today.day + 23),
  );

  ExpenseEntity spent(
    String id,
    double amount,
    String categoryId,
    DateTime day,
    int hour,
    int minute, {
    String? note,
    String? receipt,
  }) {
    final at = DateTime(day.year, day.month, day.day, hour, minute);
    return ExpenseEntity(
      id: id,
      budgetId: budget.id,
      amount: amount,
      categoryId: categoryId,
      note: note,
      date: day,
      time: at,
      receiptImagePath: receipt,
      createdAt: at,
      updatedAt: at,
    );
  }

  final list = [
    spent('lunch', 390, 'food', today, 12, 40, note: 'Lunch'),
    spent('fuel', 1250.5, 'fuel', today, 9, 15),
    spent('veg', 642, 'grocery', today, 8, 5, note: 'Vegetables and fruit'),
    spent(
      'gift',
      2200,
      'shopping',
      yesterday,
      19,
      30,
      note: 'Birthday gift for Ananya',
      receipt: '/missing/receipt.jpg',
    ),
    spent('cab', 318, 'travel', yesterday, 18, 2, note: 'Cab home'),
  ];

  testWidgets('expenses list', (tester) async {
    final state = ExpenseHistoryState(
      status: ExpenseHistoryStatus.loaded,
      allExpenses: list,
      visibleExpenses: list,
      pageExpenses: list,
      loadedExpenses: list,
      categories: defaultCategories,
      summary: const CalculateExpenseSummaryUseCase()(list),
      budgetId: budget.id,
      budgetName: budget.name,
      budgetCurrency: 'INR',
    );
    await expectGoldenMatrix(
      tester,
      'expenses_list',
      BlocProvider<ExpenseHistoryBloc>(
        create: (_) => _StaticHistoryBloc(state),
        child: const ExpenseHistoryScreen(),
      ),
      size: const Size(360, 1100),
    );
  }, skip: goldenSkip);

  testWidgets('expenses empty', (tester) async {
    final state = ExpenseHistoryState(
      status: ExpenseHistoryStatus.loaded,
      categories: defaultCategories,
      budgetId: budget.id,
      budgetName: budget.name,
      budgetCurrency: 'INR',
    );
    await expectGoldenMatrix(
      tester,
      'expenses_empty',
      BlocProvider<ExpenseHistoryBloc>(
        create: (_) => _StaticHistoryBloc(state),
        child: const ExpenseHistoryScreen(),
      ),
    );
  }, skip: goldenSkip);

  // Fixed dates where a date is drawn ("until 31 Oct", "Wed, 7 Oct 2026"),
  // so these images never change with the calendar or the time zone.
  final october = testBudget(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
  );

  testWidgets('quick add', (tester) async {
    QuickAddSheet.clock = () => DateTime(2026, 10, 8, 14);
    addTearDown(() => QuickAddSheet.clock = DateTime.now);
    final categories = defaultCategories;
    ExpenseCategory byId(String id) => categories.firstWhere((c) => c.id == id);
    final state = ExpenseState(
      categories: categories,
      quickAddLoad: QuickAddLoad.loaded,
      quickAddBudget: october,
      frequentCategories: [
        byId('food'),
        byId('grocery'),
        byId('fuel'),
        byId('travel'),
        byId('shopping'),
      ],
    );
    await expectGoldenMatrix(
      tester,
      'quick_add',
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          // Drawn like the modal sheet: its colour and top radius.
          child: Builder(
            builder: (context) => Material(
              color:
                  Theme.of(context).bottomSheetTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surfaceContainerLow,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusXl),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: BlocProvider<ExpenseBloc>(
                  create: (_) => _StaticExpenseBloc(state),
                  child: const QuickAddSheet(),
                ),
              ),
            ),
          ),
        ),
      ),
      size: const Size(360, 900),
    );
  }, skip: goldenSkip);

  testWidgets('expense details', (tester) async {
    await getIt.reset();
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(repository: StubBudgetRepository([october])),
    );
    addTearDown(getIt.reset);
    final gift = spent(
      'gift',
      2200,
      'shopping',
      DateTime(2026, 10, 7),
      19,
      30,
      note: 'Birthday gift for Ananya',
      receipt: '/missing/receipt.jpg',
    );
    final state = ExpenseState(
      status: ExpenseBlocStatus.loaded,
      expense: gift.copyWith(tags: ['family', 'birthday']),
      categories: defaultCategories,
    );
    await expectGoldenMatrix(
      tester,
      'expense_details',
      BlocProvider<ExpenseBloc>(
        create: (_) => _StaticExpenseBloc(state),
        child: const ExpenseDetailsScreen(expenseId: 'gift'),
      ),
      size: const Size(360, 900),
    );
  }, skip: goldenSkip);
}
