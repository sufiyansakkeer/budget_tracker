import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

/// Regression tests for "editing a budget amount does not update remaining".
///
/// These exercise the real BLoC-free stack (use case → repository → data
/// source → in-memory Drift database) so that the persisted `remainingAmount`
/// column, the calculation service, and every derived value are verified
/// end to end without hard-coding logic in production code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferences prefs;
  late BudgetCalculationService calculationService;
  late BudgetRepositoryImpl budgetRepository;
  late ExpenseRepositoryImpl expenseRepository;
  late ManageBudgetUseCase manageBudget;
  late GetBudgetSummaryUseCase getSummary;
  late GetSpendingTargetsUseCase getSpendingTargets;
  late GetBudgetListSummaryUseCase getListSummary;

  late DateTime today;
  late DateTime periodStart;
  late DateTime periodEnd;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    database = await createInMemoryDatabase();
    calculationService = BudgetCalculationService();

    final budgetDataSource = BudgetLocalDataSourceImpl(
      database: database,
      sharedPreferences: prefs,
    );
    budgetRepository = BudgetRepositoryImpl(
      localDataSource: budgetDataSource,
      calculationService: calculationService,
    );
    final expenseDataSource = ExpenseLocalDataSourceImpl(database: database);
    await expenseDataSource.seedDefaultCategories(defaultCategories);
    expenseRepository = ExpenseRepositoryImpl(
      localDataSource: expenseDataSource,
      budgetRepository: budgetRepository,
    );

    manageBudget = ManageBudgetUseCase(repository: budgetRepository);
    getSummary = GetBudgetSummaryUseCase(
      repository: budgetRepository,
      calculationService: calculationService,
    );
    getSpendingTargets = GetSpendingTargetsUseCase(
      repository: budgetRepository,
      calculationService: calculationService,
    );
    getListSummary = GetBudgetListSummaryUseCase(repository: budgetRepository);

    // A period that contains the real "today" so isActive/date rules apply
    // exactly as they do in the running app.
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    periodStart = today.subtract(const Duration(days: 9));
    periodEnd = today.add(const Duration(days: 20));
  });

  tearDown(() async {
    await database.close();
  });

  BudgetEntity budget(String id, double amount, {String name = 'Budget'}) {
    return BudgetEntity(
      id: id,
      name: name,
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: 'INR',
      startDate: periodStart,
      endDate: periodEnd,
      createdAt: periodStart,
      updatedAt: periodStart,
    );
  }

  Future<void> addExpense(
    String budgetId,
    double amount, {
    DateTime? date,
    String? id,
  }) async {
    final when = date ?? today;
    await expenseRepository.createExpense(
      ExpenseEntity(
        id: id ?? 'exp_${budgetId}_${DateTime.now().microsecondsSinceEpoch}',
        budgetId: budgetId,
        amount: amount,
        categoryId: defaultCategories.first.id,
        date: when,
        time: when,
        createdAt: when,
        updatedAt: when,
      ),
    );
  }

  /// Mirrors what BudgetFormScreen does: copy the loaded entity with a new
  /// amount (which carries the OLD remainingAmount) and push it through the
  /// ManageBudgetUseCase.
  Future<BudgetEntity> editAmount(String budgetId, double newAmount) async {
    final loaded = await manageBudget.getById(budgetId);
    final edited = loaded!.copyWith(
      monthlyAmount: newAmount,
      updatedAt: DateTime.now(),
    );
    return manageBudget.update(edited);
  }

  Future<BudgetEntity> stored(String id) async {
    return (await budgetRepository.getBudgetById(id))!;
  }

  group('remaining amount follows the current budget amount', () {
    test(
      'increase: 10,000 with 3,000 spent → 15,000 gives 12,000 remaining',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense('a', 3000);
        expect((await stored('a')).remainingAmount, 7000);

        final updated = await editAmount('a', 15000);

        expect(updated.monthlyAmount, 15000);
        expect(updated.remainingAmount, 12000);
        expect((await stored('a')).remainingAmount, 12000);
      },
    );

    test(
      'decrease: 10,000 with 3,000 spent → 8,000 gives 5,000 remaining',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense('a', 3000);

        final updated = await editAmount('a', 8000);

        expect(updated.remainingAmount, 5000);
        expect((await stored('a')).remainingAmount, 5000);
      },
    );

    test('no expenses: remaining always equals the current amount', () async {
      await manageBudget.create(budget('a', 10000));

      await editAmount('a', 8000);
      expect((await stored('a')).remainingAmount, 8000);

      await editAmount('a', 12500);
      expect((await stored('a')).remainingAmount, 12500);
    });

    test(
      'multiple expenses and repeated edits recalculate every time',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense(
          'a',
          1000,
          date: today.subtract(const Duration(days: 3)),
        );
        await addExpense(
          'a',
          1500,
          date: today.subtract(const Duration(days: 1)),
        );
        await addExpense('a', 500);
        expect((await stored('a')).remainingAmount, 7000);

        final steps = <double, double>{8000: 5000, 12000: 9000, 6000: 3000};
        for (final entry in steps.entries) {
          await editAmount('a', entry.key);
          final row = await stored('a');
          expect(row.monthlyAmount, entry.key);
          expect(row.remainingAmount, entry.value);
        }
      },
    );

    test('expenses outside the (edited) period are not counted', () async {
      await manageBudget.create(budget('a', 10000));
      await addExpense('a', 3000);
      await addExpense(
        'a',
        999,
        date: periodStart.subtract(const Duration(days: 1)),
      );
      expect((await stored('a')).remainingAmount, 7000);

      await editAmount('a', 15000);

      expect((await stored('a')).remainingAmount, 12000);
    });

    test('existing expenses are untouched by an amount change', () async {
      await manageBudget.create(budget('a', 10000));
      await addExpense('a', 3000, id: 'e1');
      await addExpense('a', 1200, id: 'e2');

      await editAmount('a', 15000);

      final expenses = await expenseRepository.getExpenses(budgetId: 'a');
      expect(expenses.map((e) => e.amount).toList()..sort(), [1200, 3000]);
      final stats = await budgetRepository.getBudgetStatistics('a');
      expect(stats.totalSpent, 4200);
    });
  });

  group('multiple budgets stay independent', () {
    test('only the edited budget changes', () async {
      await manageBudget.create(budget('a', 10000, name: 'A'));
      await manageBudget.create(budget('b', 20000, name: 'B'));
      await addExpense('a', 3000);
      await addExpense('b', 5000);

      await editAmount('a', 15000);

      final a = await stored('a');
      final b = await stored('b');
      expect(a.monthlyAmount, 15000);
      expect(a.remainingAmount, 12000);
      expect(b.monthlyAmount, 20000);
      expect(b.remainingAmount, 15000);
    });

    test(
      'editing a non-active budget leaves the active budget untouched',
      () async {
        await manageBudget.create(budget('a', 10000, name: 'A'));
        await manageBudget.create(budget('b', 20000, name: 'B'));
        await manageBudget.setActive('a');
        await addExpense('a', 3000);
        await addExpense('b', 5000);

        await editAmount('b', 8000);

        expect(await manageBudget.activeBudgetId(), 'a');
        final active =
            (await getSummary(budgetId: 'a', referenceDate: today))
                as BudgetSuccess;
        expect(active.data.monthlyAmount, 10000);
        expect(active.data.remainingBudget, 7000);

        final edited =
            (await getSummary(budgetId: 'b', referenceDate: today))
                as BudgetSuccess;
        expect(edited.data.monthlyAmount, 8000);
        expect(edited.data.remainingBudget, 3000);
      },
    );

    test('list summary sums each budget\'s own current remaining', () async {
      await manageBudget.create(budget('a', 10000, name: 'A'));
      await manageBudget.create(budget('b', 20000, name: 'B'));
      await addExpense('a', 3000);
      await addExpense('b', 5000);

      await editAmount('a', 15000);

      final result = await getListSummary() as BudgetSuccess;
      expect(result.data.activeBudgetCount, 2);
      expect(result.data.totalRemaining, 12000 + 15000);
    });
  });

  group('derived values use the updated amount', () {
    test('overall progress: 50% becomes 25% when the amount doubles', () async {
      await manageBudget.create(budget('a', 10000));
      await addExpense('a', 5000);

      final before =
          (await getSummary(budgetId: 'a', referenceDate: today))
              as BudgetSuccess;
      expect(before.data.budgetUtilization, closeTo(0.5, 1e-9));
      expect(before.data.spendingPercentage, closeTo(50, 1e-9));

      await editAmount('a', 20000);

      final after =
          (await getSummary(budgetId: 'a', referenceDate: today))
              as BudgetSuccess;
      expect(after.data.monthlyAmount, 20000);
      expect(after.data.remainingBudget, 15000);
      expect(after.data.budgetUtilization, closeTo(0.25, 1e-9));
      expect(after.data.spendingPercentage, closeTo(25, 1e-9));
    });

    test(
      'daily safe spending is recalculated from the new remaining',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense(
          'a',
          2000,
          date: today.subtract(const Duration(days: 2)),
        );
        await addExpense('a', 1000); // spent today

        await editAmount('a', 15000);

        final remainingDays = budget('a', 0).daysRemaining(today);
        final expectedDaily = calculationService.calculateDailyAllowance(
          remainingBudget: 12000 + 1000,
          remainingDays: remainingDays,
        );

        // Dashboard summary path.
        final summary =
            (await getSummary(budgetId: 'a', referenceDate: today))
                as BudgetSuccess;
        expect(summary.data.dailySafeSpending, closeTo(expectedDaily, 1e-9));

        // "Today's Safe Spending" / home-widget / notification path, which
        // reads the persisted remainingAmount column.
        final targets =
            await getSpendingTargets.callPerBudget(referenceDate: today)
                as PerBudgetSpendingTargetSuccess;
        final limit = targets.budgetLimits.singleWhere(
          (l) => l.budgetId == 'a',
        );
        expect(limit.monthlyAmount, 15000);
        expect(limit.totalSpent, 3000);
        expect(limit.remainingBudget, 12000);
        expect(limit.dailyLimit, closeTo(expectedDaily, 1e-9));
        expect(limit.budgetUtilization, closeTo(3000 / 15000, 1e-9));
      },
    );

    test('summary and per-budget limits agree after the edit', () async {
      await manageBudget.create(budget('a', 10000));
      await addExpense('a', 3000);
      await editAmount('a', 8000);

      final summary =
          (await getSummary(budgetId: 'a', referenceDate: today))
              as BudgetSuccess;
      final targets =
          await getSpendingTargets.callPerBudget(referenceDate: today)
              as PerBudgetSpendingTargetSuccess;
      final limit = targets.budgetLimits.singleWhere((l) => l.budgetId == 'a');

      expect(limit.remainingBudget, summary.data.remainingBudget);
      expect(limit.dailyLimit, closeTo(summary.data.dailySafeSpending, 1e-9));
      expect(
        limit.budgetUtilization,
        closeTo(summary.data.budgetUtilization, 1e-9),
      );
    });
  });

  group('persistence', () {
    test(
      'updated amount and remaining survive a fresh repository (restart)',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense('a', 3000);
        await editAmount('a', 15000);

        // Simulate a restart: brand-new data source, repository, and use cases
        // over the same database file.
        final freshRepository = BudgetRepositoryImpl(
          localDataSource: BudgetLocalDataSourceImpl(
            database: database,
            sharedPreferences: prefs,
          ),
          calculationService: BudgetCalculationService(),
        );
        final freshSummary = GetBudgetSummaryUseCase(
          repository: freshRepository,
          calculationService: BudgetCalculationService(),
        );

        final row = await (database.select(
          database.budgets,
        )..where((b) => b.id.equals('a'))).getSingle();
        expect(row.monthlyAmount, 15000);
        expect(row.remainingAmount, 12000);

        final reloaded = await freshRepository.getBudgetById('a');
        expect(reloaded!.monthlyAmount, 15000);
        expect(reloaded.remainingAmount, 12000);

        final summary =
            (await freshSummary(budgetId: 'a', referenceDate: today))
                as BudgetSuccess;
        expect(summary.data.remainingBudget, 12000);
      },
    );

    test('a later expense change builds on the updated amount', () async {
      await manageBudget.create(budget('a', 10000));
      await addExpense('a', 3000);
      await editAmount('a', 15000);

      await addExpense('a', 2000);

      expect((await stored('a')).remainingAmount, 10000);
    });
  });

  group('related budget operations', () {
    test(
      'a duplicated budget starts with remaining equal to its amount',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense('a', 3000);

        final copy = await manageBudget.duplicate('a', newName: 'Copy');

        expect(copy.monthlyAmount, 10000);
        expect(copy.remainingAmount, 10000);
        expect((await stored(copy.id)).remainingAmount, 10000);
        // Source untouched.
        expect((await stored('a')).remainingAmount, 7000);
      },
    );

    test(
      'archiving and restoring does not alter amount or remaining',
      () async {
        await manageBudget.create(budget('a', 10000));
        await addExpense('a', 3000);
        await editAmount('a', 15000);

        await manageBudget.archive('a', archived: true);
        var row = await stored('a');
        expect(row.isArchived, isTrue);
        expect(row.monthlyAmount, 15000);
        expect(row.remainingAmount, 12000);

        await manageBudget.archive('a', archived: false);
        row = await stored('a');
        expect(row.isArchived, isFalse);
        expect(row.remainingAmount, 12000);
      },
    );

    test('editing an archived budget does not touch other budgets', () async {
      await manageBudget.create(budget('old', 10000, name: 'Old'));
      await manageBudget.create(budget('cur', 20000, name: 'Current'));
      await addExpense('old', 4000);
      await addExpense('cur', 5000);
      await manageBudget.archive('old', archived: true);

      await editAmount('old', 12000);

      expect((await stored('old')).remainingAmount, 8000);
      expect((await stored('old')).isArchived, isTrue);
      expect((await stored('cur')).monthlyAmount, 20000);
      expect((await stored('cur')).remainingAmount, 15000);
    });
  });
}
