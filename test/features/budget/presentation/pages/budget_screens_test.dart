import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_surface.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_details_screen.dart';
import 'package:monivo/features/budget/presentation/pages/budget_list_screen.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_list_items.dart';

import '../../../../helpers/bill_ui_fakes.dart';

/// Budgets whose statistics can be set per budget.
class _StatsBudgetRepository extends ListBudgetRepository {
  final Map<String, MonthlyStatisticsEntity> stats;

  _StatsBudgetRepository(
    super.budgets,
    super.activeId, {
    this.stats = const {},
  });

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => stats[budgetId] ?? MonthlyStatisticsEntity.empty;
}

BudgetEntity _budget(
  String id,
  String name, {
  required DateTime start,
  required DateTime end,
  double amount = 30000,
  double? remaining,
  String currency = 'INR',
  bool archived = false,
}) => BudgetEntity(
  id: id,
  name: name,
  monthlyAmount: amount,
  remainingAmount: remaining ?? amount,
  currency: currency,
  startDate: start,
  endDate: end,
  isArchived: archived,
  createdAt: start,
  updatedAt: start,
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  final household = _budget(
    'household',
    'Household',
    start: day(-8),
    end: day(22),
    amount: 60000,
    remaining: 25103,
  );
  final personal = _budget(
    'personal',
    'Personal',
    start: day(-2),
    end: day(27),
    amount: 9000,
    remaining: 7380,
  );
  final muscat = _budget(
    'muscat',
    'Muscat',
    start: day(-3),
    end: day(26),
    amount: 300,
    remaining: 120.5,
    currency: 'OMR',
  );
  final nextYear = _budget('next', 'Next trip', start: day(40), end: day(60));
  final oldTrip = _budget(
    'old',
    'Old trip',
    start: day(-90),
    end: day(-60),
    archived: true,
  );

  late _StatsBudgetRepository repository;

  Future<void> register(
    List<BudgetEntity> budgets,
    String? activeId, {
    Map<String, MonthlyStatisticsEntity> stats = const {},
  }) async {
    await getIt.reset();
    repository = _StatsBudgetRepository(budgets, activeId, stats: stats);
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(repository: repository),
      )
      ..registerSingleton<BudgetRepository>(repository)
      ..registerSingleton<GetBudgetListSummaryUseCase>(
        GetBudgetListSummaryUseCase(repository: repository),
      );
  }

  tearDown(() => getIt.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(400, 1200),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Budgets list', () {
    testWidgets('the active budget leads as the one raised card, the rest '
        'are compact rows', (tester) async {
      await register([
        personal,
        household,
        muscat,
        nextYear,
        oldTrip,
      ], 'household');
      await pump(tester, const BudgetListScreen());

      expect(find.byType(AppSurface), findsOneWidget);
      expect(find.byType(ActiveBudgetCard), findsOneWidget);
      expect(
        find.text('Home, Expenses and Reports follow this budget'),
        findsOneWidget,
      );
      expect(find.byType(BudgetRow), findsNWidgets(4));
      expect(find.text('Also running today'), findsOneWidget);
      expect(find.text('Starting later'), findsOneWidget);
      expect(find.text('Archived'), findsWidgets);

      // The active card comes first, the footer last.
      final card = tester.getTopLeft(find.byType(ActiveBudgetCard)).dy;
      final rows = tester.getTopLeft(find.text('Also running today')).dy;
      final footer = tester.getTopLeft(find.text('Total remaining')).dy;
      expect(card, lessThan(rows));
      expect(rows, lessThan(footer));
    });

    testWidgets('the footer gives one total per currency, never pooled', (
      tester,
    ) async {
      await register([household, personal, muscat], 'household');
      await pump(tester, const BudgetListScreen());

      expect(
        find.text(AppMoney.format(25103 + 7380, currency: 'INR')),
        findsOneWidget,
      );
      expect(find.text(AppMoney.format(120.5, currency: 'OMR')), findsWidgets);
      expect(find.text('Across 3 budgets running today'), findsOneWidget);
    });

    testWidgets('an overspent budget reads "over", in the critical tone', (
      tester,
    ) async {
      await register([
        household,
        personal.copyWith(remainingAmount: -1200),
      ], 'household');
      await pump(tester, const BudgetListScreen());

      expect(find.text('over'), findsOneWidget);
      expect(find.text(AppMoney.format(1200, currency: 'INR')), findsOneWidget);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
        await register([
          household,
          personal,
          muscat,
          nextYear,
          oldTrip,
        ], 'household');
        await pump(
          tester,
          const BudgetListScreen(),
          size: Size(width, 1600),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Budget details', () {
    testWidgets('the active budget offers "Add expense"', (tester) async {
      await register([household, personal], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      expect(find.byKey(const Key('budgetAddExpense')), findsOneWidget);
      expect(find.byKey(const Key('budgetMakeActive')), findsNothing);
      expect(
        find.text('Home, Expenses and Reports follow this budget'),
        findsOneWidget,
      );
    });

    testWidgets('another budget offers "Make active" instead of adding to '
        'the active one (review: it recorded into the active budget)', (
      tester,
    ) async {
      await register([household, personal], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'personal'));

      expect(find.byKey(const Key('budgetAddExpense')), findsNothing);
      expect(find.text('Not your active budget'), findsOneWidget);

      await tester.tap(find.byKey(const Key('budgetMakeActive')));
      await tester.pumpAndSettle();
      expect(repository.activeId, 'personal');
      expect(find.byKey(const Key('budgetAddExpense')), findsOneWidget);
    });

    testWidgets('an archived budget offers neither, only Restore', (
      tester,
    ) async {
      await register([household, oldTrip], 'household');
      await pump(tester, const BudgetDetailsScreen(budgetId: 'old'));

      expect(find.byKey(const Key('budgetAddExpense')), findsNothing);
      expect(find.byKey(const Key('budgetMakeActive')), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('shows what is left on one surface with plain figures', (
      tester,
    ) async {
      await register(
        [household],
        'household',
        stats: {
          'household': const MonthlyStatisticsEntity(
            totalSpent: 34897,
            expenseCount: 21,
            todaySpending: 570,
          ),
        },
      );
      await pump(tester, const BudgetDetailsScreen(budgetId: 'household'));

      expect(find.byType(AppSurface), findsOneWidget);
      expect(
        find.text(AppMoney.format(25103, currency: 'INR')),
        findsOneWidget,
      );
      expect(find.text('Spent today'), findsOneWidget);
      expect(find.text(AppMoney.format(570, currency: 'INR')), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.textContaining('58% used'), findsOneWidget);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
        await register([household, personal], 'household');
        await pump(
          tester,
          const BudgetDetailsScreen(budgetId: 'personal'),
          size: Size(width, 1600),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
