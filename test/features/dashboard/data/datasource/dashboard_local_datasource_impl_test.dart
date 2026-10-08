import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/data/models/budget_model.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/dashboard/data/datasource/dashboard_local_datasource_impl.dart';
import 'package:monivo/features/dashboard/data/repository/dashboard_repository_impl.dart';
import 'package:monivo/features/dashboard/domain/entities/committed_spending.dart';

import '../../../../helpers/in_memory_database.dart';

/// Committed spending (expenses with a `bill_id`) summed in SQL per budget,
/// with the same calendar-day bounds as the budget statistics.
void main() {
  late AppDatabase database;
  late DashboardRepositoryImpl repository;

  // House fixture month: Aug 2026; "today" is Aug 20.
  final today = DateTime(2026, 8, 20, 15, 45);
  var seq = 0;

  Future<void> insertBudget(
    String id, {
    required DateTime start,
    required DateTime end,
  }) async {
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            name: 'Budget $id',
            monthlyAmount: 500,
            remainingAmount: 500,
            currency: 'OMR',
            startDate: start,
            endDate: end,
            reservedAmount: const Value(40),
            savingsTarget: const Value(60),
          ),
        );
  }

  Future<void> insertExpense(
    String budgetId,
    double amount,
    DateTime date, {
    String? billId,
  }) async {
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'e${seq++}',
            budgetId: budgetId,
            amount: amount,
            categoryId: 'bills',
            date: date,
            time: Value(date),
            billId: Value(billId),
          ),
        );
  }

  Future<List<BudgetEntity>> budgets() async =>
      (await database.select(database.budgets).get())
          .map(BudgetModel.toEntity)
          .toList();

  setUp(() async {
    database = await createInMemoryDatabase();
    repository = DashboardRepositoryImpl(
      localDataSource: DashboardLocalDataSourceImpl(database: database),
    );
    seq = 0;
  });

  tearDown(() => database.close());

  group('getCommittedSpending', () {
    test('sums only bill-linked expenses inside the period', () async {
      await insertBudget(
        'b1',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      // Committed, inside the period (first and last instant of the period).
      await insertExpense('b1', 100, DateTime(2026, 8, 1), billId: 'rent');
      await insertExpense(
        'b1',
        25.5,
        DateTime(2026, 8, 31, 23, 59),
        billId: 'net',
      );
      // Committed today.
      await insertExpense('b1', 30, DateTime(2026, 8, 20, 8), billId: 'gym');
      await insertExpense('b1', 4.25, DateTime(2026, 8, 20, 23), billId: 'x');
      // Plain spending: never committed.
      await insertExpense('b1', 999, DateTime(2026, 8, 20, 10));
      // Committed but outside the period.
      await insertExpense('b1', 77, DateTime(2026, 7, 31, 23), billId: 'old');
      await insertExpense('b1', 88, DateTime(2026, 9, 1), billId: 'next');

      final result = await repository.getCommittedSpending(
        budgets: await budgets(),
        today: today,
      );

      expect(
        result['b1'],
        const CommittedSpending(periodTotal: 159.75, todayTotal: 34.25),
      );
    });

    test('keeps budgets independent', () async {
      await insertBudget(
        'b1',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      await insertBudget(
        'b2',
        start: DateTime(2026, 8, 15),
        end: DateTime(2026, 8, 25),
      );
      await insertExpense('b1', 100, DateTime(2026, 8, 20), billId: 'rent');
      await insertExpense('b2', 40, DateTime(2026, 8, 16), billId: 'phone');

      final result = await repository.getCommittedSpending(
        budgets: await budgets(),
        today: today,
      );

      expect(
        result['b1'],
        const CommittedSpending(periodTotal: 100, todayTotal: 100),
      );
      expect(
        result['b2'],
        const CommittedSpending(periodTotal: 40, todayTotal: 0),
      );
    });

    test('today outside the period contributes nothing today', () async {
      await insertBudget(
        'ended',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );
      await insertBudget(
        'future',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      await insertExpense('ended', 50, DateTime(2026, 7, 10), billId: 'a');
      // Dated today but outside both periods: not counted anywhere.
      await insertExpense('ended', 60, DateTime(2026, 8, 20), billId: 'b');
      await insertExpense('future', 70, DateTime(2026, 8, 20), billId: 'c');

      final result = await repository.getCommittedSpending(
        budgets: await budgets(),
        today: today,
      );

      expect(
        result['ended'],
        const CommittedSpending(periodTotal: 50, todayTotal: 0),
      );
      expect(result['future'], CommittedSpending.zero);
    });

    test('a budget whose dates carry a time of day uses whole days', () async {
      await insertBudget(
        'b1',
        start: DateTime(2026, 8, 1, 18),
        end: DateTime(2026, 8, 31, 6),
      );
      await insertExpense('b1', 10, DateTime(2026, 8, 1, 7), billId: 'a');
      await insertExpense('b1', 20, DateTime(2026, 8, 31, 22), billId: 'b');

      final result = await repository.getCommittedSpending(
        budgets: await budgets(),
        today: today,
      );

      expect(result['b1']!.periodTotal, 30);
    });

    test('every budget gets an entry; none gives an empty map', () async {
      await insertBudget(
        'b1',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );

      expect(
        await repository.getCommittedSpending(
          budgets: await budgets(),
          today: today,
        ),
        {'b1': CommittedSpending.zero},
      );
      expect(
        await repository.getCommittedSpending(budgets: const [], today: today),
        isEmpty,
      );
    });
  });

  group('getRecentExpenses', () {
    test('is still scoped to the budget period', () async {
      await insertBudget(
        'b1',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      await insertExpense('b1', 10, DateTime(2026, 8, 5));
      await insertExpense('b1', 20, DateTime(2026, 7, 30));

      final recent = await repository.getRecentExpenses(
        budgetId: 'b1',
        referenceDate: today,
      );

      expect(recent.map((e) => e.amount), [10]);
    });
  });
}
