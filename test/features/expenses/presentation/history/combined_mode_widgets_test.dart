import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_for_budgets_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:monivo/features/expenses/presentation/history/bloc/expense_history_state.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/budget_info_bottom_sheet.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/budget_selection_sheet.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_history_empty_state.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_history_item.dart';

// ── Helpers ────────────────────────────────────────────────────────────

ExpenseEntity expense({
  required String id,
  required String budgetId,
  double amount = 100,
  String categoryId = 'food',
  String? note,
}) {
  final now = DateTime(2026, 8, 20);
  return ExpenseEntity(
    id: id,
    budgetId: budgetId,
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: now,
    time: now,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetEntity budgetEntity({
  required String id,
  required String name,
  double monthlyAmount = 30000,
  double spent = 5000,
}) {
  return BudgetEntity(
    id: id,
    name: name,
    monthlyAmount: monthlyAmount,
    remainingAmount: monthlyAmount - spent,
    currency: 'INR',
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 31),
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

class FakeRepository implements ExpenseRepository {
  final List<ExpenseEntity> expenses;
  FakeRepository(this.expenses);

  @override
  Future<void> createExpense(ExpenseEntity e) async {}
  @override
  Future<void> updateExpense(ExpenseEntity e) async {}
  @override
  Future<void> deleteExpense(String id) async {}
  @override
  Future<ExpenseEntity?> getExpenseById(String id) async => null;
  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
  }) async => expenses;
  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async => expenses.where((e) => budgetIds.contains(e.budgetId)).toList();
  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
}

class FakeBudgetRepo implements BudgetRepository {
  final List<BudgetEntity> budgets;
  FakeBudgetRepo(this.budgets);

  @override
  Future<BudgetEntity?> getActiveBudget() async => budgets.firstOrNull;
  @override
  Future<String?> getActiveBudgetId() async => budgets.firstOrNull?.id;
  @override
  Future<void> setActiveBudgetId(String budgetId) async {}
  @override
  Future<BudgetEntity?> getBudgetById(String id) async =>
      budgets.where((b) => b.id == id).firstOrNull;
  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async => budgets;
  @override
  Future<BudgetEntity> createBudget(BudgetEntity b) async => b;
  @override
  Future<BudgetEntity> updateBudget(BudgetEntity b) async => b;
  @override
  Future<void> deleteBudget(String id) async {}
  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async => budgets.first;
  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => budgets.first;
  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => MonthlyStatisticsEntity.empty;
  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 0;
  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 1;
  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async =>
      BudgetError(BudgetFailure(type: BudgetErrorType.notFound, message: ''));
  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}
  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0;
}

Widget wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────

void main() {
  group('ExpenseHistoryItem — combined mode', () {
    testWidgets('shows budget name chip and info icon when in combined mode', (
      tester,
    ) async {
      final entity = expense(
        id: '1',
        budgetId: 'food',
        amount: 250,
        note: 'Pizza',
      );
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryItem(
            expense: entity,
            category: defaultCategories.first,
            budgetName: 'Food',
            onInfoTap: () {},
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Food'), findsWidgets); // category name + budget chip
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
    });

    testWidgets('hides info icon when onInfoTap is null (single budget mode)', (
      tester,
    ) async {
      final entity = expense(
        id: '1',
        budgetId: 'food',
        amount: 250,
        note: 'Pizza',
      );
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryItem(
            expense: entity,
            category: defaultCategories.first,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });

    testWidgets('hides budget chip when budgetName is null', (tester) async {
      final entity = expense(id: '1', budgetId: 'food', amount: 250);
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryItem(
            expense: entity,
            category: defaultCategories.first,
            onTap: () {},
          ),
        ),
      );

      // Should only find the category name 'Food', not a separate budget chip
      expect(find.text('Food'), findsOneWidget);
    });
  });

  group('BudgetInfoBottomSheet', () {
    testWidgets('displays budget name, amount, date, and time', (tester) async {
      final entity = expense(
        id: '1',
        budgetId: 'food',
        amount: 500,
        note: 'Restaurant',
      );
      final budg = budgetEntity(id: 'food', name: 'Food');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => BudgetInfoBottomSheet.show(
                  context: context,
                  expense: entity,
                  budget: budg,
                  categoryName: 'Food',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Expense Information'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
    });
  });

  group('BudgetSelectionSheet', () {
    testWidgets('shows header and apply button', (tester) async {
      final budgets = [
        budgetEntity(id: 'food', name: 'Food', spent: 2500),
        budgetEntity(id: 'travel', name: 'Travel', spent: 1500),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await BudgetSelectionSheet.show(
                    context: context,
                    allBudgets: budgets,
                    initiallySelected: ['food'],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Budgets'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
    });

    testWidgets('applies with empty selection shows snackbar', (tester) async {
      final budgets = [budgetEntity(id: 'food', name: 'Food')];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await BudgetSelectionSheet.show(
                    context: context,
                    allBudgets: budgets,
                    initiallySelected: [],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Apply with nothing selected
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Select at least one budget'), findsOneWidget);
    });
  });

  group('ExpenseHistoryEmptyState — combined', () {
    testWidgets('shows empty state with clear filters', (tester) async {
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryEmptyState(
            hasAnyExpenses: true,
            hasSearchQuery: true,
            hasActiveFilters: false,
            onAddFirst: () {},
            onClearFilters: () {},
          ),
        ),
      );

      expect(find.text('No search results'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);
    });
  });
}
