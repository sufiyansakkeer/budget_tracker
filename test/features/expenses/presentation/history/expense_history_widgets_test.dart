import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_category.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_entity.dart';
import 'package:budget_tracker/features/expenses/domain/entities/expense_group.dart';
import 'package:budget_tracker/features/expenses/domain/repository/expense_repository.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/calculate_expense_summary_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/filter_expenses_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/page_expenses_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/search_expenses_usecase.dart';
import 'package:budget_tracker/features/expenses/domain/usecases/sort_expenses_usecase.dart';
import 'package:budget_tracker/features/expenses/presentation/history/bloc/expense_history_bloc.dart';
import 'package:budget_tracker/features/expenses/presentation/history/bloc/expense_history_event.dart';
import 'package:budget_tracker/features/expenses/presentation/history/bloc/expense_history_state.dart';
import 'package:budget_tracker/features/expenses/presentation/history/pages/expense_history_screen.dart';
import 'package:budget_tracker/features/expenses/presentation/history/widgets/expense_group_header.dart';
import 'package:budget_tracker/features/expenses/presentation/history/widgets/expense_history_empty_state.dart';
import 'package:budget_tracker/features/expenses/presentation/history/widgets/expense_history_error_widget.dart';
import 'package:budget_tracker/features/expenses/presentation/history/widgets/expense_history_item.dart';
import 'package:budget_tracker/features/expenses/presentation/history/widgets/expense_search_bar.dart';
import 'package:budget_tracker/features/expenses/presentation/history/widgets/sort_bottom_sheet.dart';

ExpenseEntity expense({
  required String id,
  double amount = 100,
  String categoryId = 'food',
  String? note,
  DateTime? date,
  String? receiptPath,
}) {
  final now = date ?? DateTime(2026, 8, 5);
  return ExpenseEntity(
    id: id,
    amount: amount,
    categoryId: categoryId,
    note: note,
    date: now,
    time: now,
    receiptImagePath: receiptPath,
    createdAt: now,
    updatedAt: now,
  );
}

class FakeHistoryRepository implements ExpenseRepository {
  final List<ExpenseEntity> expenses;
  FakeHistoryRepository(this.expenses);

  @override
  Future<void> createExpense(ExpenseEntity expense) async {}
  @override
  Future<void> updateExpense(ExpenseEntity expense) async {}
  @override
  Future<void> deleteExpense(String id) async {}
  @override
  Future<ExpenseEntity?> getExpenseById(String id) async => null;
  @override
  Future<List<ExpenseEntity>> getExpenses({int? month, int? year}) async =>
      expenses;
  @override
  Future<List<ExpenseCategory>> getCategories() async => defaultCategories;
}

ExpenseHistoryBloc buildBloc(ExpenseRepository repository) {
  return ExpenseHistoryBloc(
    getExpensesUseCase: GetExpensesUseCase(repository: repository),
    getCategoriesUseCase: GetCategoriesUseCase(repository: repository),
    searchExpensesUseCase: const SearchExpensesUseCase(),
    filterExpensesUseCase: const FilterExpensesUseCase(),
    sortExpensesUseCase: const SortExpensesUseCase(),
    calculateExpenseSummaryUseCase: const CalculateExpenseSummaryUseCase(),
    pageExpensesUseCase: const PageExpensesUseCase(pageSize: 20),
  );
}

Widget wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('ExpenseHistoryItem', () {
    testWidgets('renders category, amount, note, and receipt indicator', (
      tester,
    ) async {
      final entity = expense(
        id: '1',
        amount: 250,
        note: 'Pizza',
        receiptPath: '/tmp/receipt.jpg',
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

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
    });
  });

  group('ExpenseGroupHeader', () {
    testWidgets('renders group label and item count', (tester) async {
      final group = ExpenseGroup(
        type: ExpenseGroupType.today,
        expenses: [
          expense(id: '1'),
          expense(id: '2'),
        ],
      );
      await tester.pumpWidget(wrap(ExpenseGroupHeader(group: group)));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
    });
  });

  group('ExpenseSearchBar', () {
    testWidgets('shows clear button when text present', (tester) async {
      final controller = TextEditingController(text: 'lunch');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          ExpenseSearchBar(
            controller: controller,
            onChanged: (_) {},
            onClear: () => controller.clear(),
          ),
        ),
      );

      expect(find.byKey(const Key('expenseSearchClear')), findsOneWidget);
    });
  });

  group('SortBottomSheet', () {
    testWidgets('shows all sort options', (tester) async {
      await tester.pumpWidget(
        wrap(SortBottomSheet(current: ExpenseSortOption.newestFirst)),
      );

      expect(find.text('Newest First'), findsOneWidget);
      expect(find.text('Oldest First'), findsOneWidget);
      expect(find.text('Highest Amount'), findsOneWidget);
      expect(find.text('Lowest Amount'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Alphabetical'), findsOneWidget);
    });
  });

  group('ExpenseHistoryEmptyState', () {
    testWidgets('shows add-first-expense action', (tester) async {
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryEmptyState(
            hasAnyExpenses: false,
            hasSearchQuery: false,
            hasActiveFilters: false,
            onAddFirst: () {},
            onClearFilters: () {},
          ),
        ),
      );

      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Add Your First Expense'), findsOneWidget);
    });

    testWidgets('shows clear filters action when filtered', (tester) async {
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryEmptyState(
            hasAnyExpenses: true,
            hasSearchQuery: false,
            hasActiveFilters: true,
            onAddFirst: () {},
            onClearFilters: () {},
          ),
        ),
      );

      expect(find.text('No filtered results'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);
    });
  });

  group('ExpenseHistoryErrorWidget', () {
    testWidgets('shows message and retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryErrorWidget(
            message: 'DB failure',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('DB failure'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('ExpenseHistoryScreen', () {
    testWidgets('renders empty state when no expenses', (tester) async {
      final bloc = buildBloc(FakeHistoryRepository(const []));
      addTearDown(bloc.close);
      // Pre-load so the widget renders the loaded state immediately.
      bloc.add(const ExpenseHistoryLoad());
      await bloc.stream.firstWhere(
        (s) => s.status == ExpenseHistoryStatus.loaded,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<ExpenseHistoryBloc>.value(
            value: bloc,
            child: const ExpenseHistoryScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No expenses yet'), findsOneWidget);
    });

    testWidgets('renders list when expenses exist', (tester) async {
      final bloc = buildBloc(
        FakeHistoryRepository([
          expense(
            id: '1',
            amount: 100,
            note: 'Groceries',
            categoryId: 'grocery',
          ),
          expense(id: '2', amount: 200, note: 'Gas', categoryId: 'fuel'),
        ]),
      );
      addTearDown(bloc.close);
      bloc.add(const ExpenseHistoryLoad());
      await bloc.stream.firstWhere(
        (s) => s.status == ExpenseHistoryStatus.loaded,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<ExpenseHistoryBloc>.value(
            value: bloc,
            child: const ExpenseHistoryScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Gas'), findsOneWidget);
      expect(find.byType(ExpenseSearchBar), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
    });
  });
}
