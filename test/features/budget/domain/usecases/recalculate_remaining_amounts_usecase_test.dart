import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/budget/domain/usecases/recalculate_remaining_amounts_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/domain/services/import_service.dart';

import '../../../../integration/app_harness.dart';

/// The budget list reads each budget's stored remaining amount. Writes that
/// go straight to the database (import, restore) left it stale (review: the
/// list disagreed with the dashboard until that budget's next expense).
void main() {
  late AppHarness app;
  late RecalculateRemainingAmountsUseCase recalculate;
  late Directory dir;

  setUp(() async {
    app = await AppHarness.create();
    recalculate = RecalculateRemainingAmountsUseCase(
      repository: app.budgetRepository,
      calculationService: app.calculationService,
    );
    dir = await Directory.systemTemp.createTemp('remaining_');
    await app.addBudget(
      id: 'a',
      amount: 10000,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
  });

  tearDown(() async {
    await app.dispose();
    await dir.delete(recursive: true);
  });

  /// Writes an expense the way import and restore do: no repository, so
  /// the stored remaining amount is not touched.
  Future<void> insertDirectly(String id, double amount, DateTime date) => app
      .database
      .into(app.database.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: id,
          budgetId: 'a',
          amount: amount,
          categoryId: 'food',
          date: date,
        ),
      );

  test('repairs a stale value from the period total; correct ones are '
      'left alone', () async {
    await app.addBudget(
      id: 'b',
      amount: 5000,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      makeActive: false,
    );
    await app.expenseRepository.createExpense(
      ExpenseEntity(
        id: 'b1',
        budgetId: 'b',
        amount: 1000,
        categoryId: 'food',
        date: DateTime(2026, 8, 5),
        time: DateTime(2026, 8, 5, 9),
        createdAt: DateTime(2026, 8, 5),
        updatedAt: DateTime(2026, 8, 5),
      ),
    );
    await insertDirectly('a1', 2500, DateTime(2026, 8, 10));
    // Before the period: not part of the remaining, as on the dashboard.
    await insertDirectly('a0', 700, DateTime(2026, 7, 30));
    expect(await app.storedRemaining('a'), 10000, reason: 'stale');

    expect(await recalculate(), 1);
    expect(await app.storedRemaining('a'), 7500);
    expect(await app.storedRemaining('b'), 4000);

    final stats = await app.budgetRepository.getBudgetStatistics('a');
    expect(await app.storedRemaining('a'), 10000 - stats.totalSpent);

    expect(await recalculate(), 0, reason: 'nothing left to repair');
  });

  test('a JSON import whose file carries a wrong remaining amount ends with '
      'the right one', () async {
    final payload = await BackupService(
      database: app.database,
    ).buildBackupPayload();
    final data = payload['data']! as Map<String, Object?>;
    (data['budgets']! as List)
            .cast<Map<String, Object?>>()
            .single['remainingAmount'] =
        99999.0;
    data['expenses'] = [
      {
        'id': 'imported',
        'budgetId': 'a',
        'amount': 1200.0,
        'categoryId': 'food',
        'date': DateTime(2026, 8, 12).toIso8601String(),
        'time': DateTime(2026, 8, 12, 9).toIso8601String(),
        'createdAt': DateTime(2026, 8, 12, 9).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 12, 9).toIso8601String(),
        'tags': <String>[],
      },
    ];
    final file = File('${dir.path}/import.json');
    await file.writeAsString(jsonEncode(payload));

    await ImportService(
      database: app.database,
      recalculateRemaining: recalculate,
    ).importJson(file.path);

    expect(await app.storedRemaining('a'), 8800);
  });

  test('a CSV import refreshes the budget it adds expenses to', () async {
    final file = File('${dir.path}/import.csv');
    await file.writeAsString(
      'amount,categoryId,note,date,budgetId\n'
      '300.0,food,Lunch,2026-08-10,a\n'
      '450.5,food,Dinner,2026-08-11,a\n',
    );

    await ImportService(
      database: app.database,
      recalculateRemaining: recalculate,
    ).importCsv(file.path);

    expect(await app.storedRemaining('a'), 10000 - 750.5);
  });

  test('a restore whose backup carries a wrong remaining amount ends with '
      'the right one', () async {
    await app.expenseRepository.createExpense(
      ExpenseEntity(
        id: 'a1',
        budgetId: 'a',
        amount: 2000,
        categoryId: 'food',
        date: DateTime(2026, 8, 3),
        time: DateTime(2026, 8, 3, 9),
        createdAt: DateTime(2026, 8, 3),
        updatedAt: DateTime(2026, 8, 3),
      ),
    );
    final backup = BackupService(
      database: app.database,
      recalculateRemaining: recalculate,
    );
    final payload = await backup.buildBackupPayload();
    ((payload['data']! as Map<String, Object?>)['budgets']! as List)
            .cast<Map<String, Object?>>()
            .single['remainingAmount'] =
        10000.0;
    final file = File('${dir.path}/backup.json');
    await file.writeAsString(jsonEncode(payload));

    await backup.restore(file.path);

    expect(await app.storedRemaining('a'), 8000);
  });
}
