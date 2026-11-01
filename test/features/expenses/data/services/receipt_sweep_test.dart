import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/expenses/data/services/receipt_storage_service.dart';

import '../../../../helpers/in_memory_database.dart';

/// Copied receipt files were never deleted: not when an expense was
/// deleted, a receipt replaced or removed, or a form discarded.
void main() {
  late AppDatabase database;
  late Directory receipts;

  setUp(() async {
    database = await createInMemoryDatabase();
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget-1',
            name: 'Personal',
            monthlyAmount: 100,
            remainingAmount: 100,
            currency: 'OMR',
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 10, 31),
          ),
        );
    receipts = Directory.systemTemp.createTempSync('monivo_receipts_');
  });

  tearDown(() async {
    await database.close();
    receipts.deleteSync(recursive: true);
  });

  Future<void> expenseWithReceipt(String id, String? path) => database
      .into(database.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: id,
          budgetId: 'budget-1',
          amount: 5,
          categoryId: 'food',
          date: DateTime(2026, 10, 1),
          receiptImagePath: Value(path),
        ),
      );

  File receipt(String name) =>
      File('${receipts.path}/$name')..writeAsStringSync('jpg');

  test(
    'deletes the receipts no expense points to, and keeps the rest',
    () async {
      final kept = receipt('1_kept.jpg');
      final orphan = receipt('2_orphan.jpg');
      await expenseWithReceipt('e1', kept.path);
      await expenseWithReceipt('e2', null);

      final deleted = await ReceiptStorageService.deleteUnreferencedIn(
        receipts,
        database,
      );

      expect(deleted, 1);
      expect(kept.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
    },
  );

  test('matches by file name: iOS moves the app folder on updates', () async {
    final kept = receipt('1_kept.jpg');
    await expenseWithReceipt(
      'e1',
      '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/'
          'receipts/1_kept.jpg',
    );

    final deleted = await ReceiptStorageService.deleteUnreferencedIn(
      receipts,
      database,
    );

    expect(deleted, 0);
    expect(kept.existsSync(), isTrue);
  });
}
