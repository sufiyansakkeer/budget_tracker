import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/expenses/data/models/expense_model.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/domain/services/export_service.dart';
import 'package:monivo/features/settings/domain/services/import_service.dart';

import '../../../../helpers/in_memory_database.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/pay_later_fixtures.dart';

void main() {
  late AppDatabase database;
  late BackupService backupService;

  setUp(() async {
    database = await createInMemoryDatabase();
    backupService = BackupService(
      database: database,
      reconcileTabs: reconcileTabsOn(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedData() async {
    final now = DateTime(2024, 1, 10, 12, 0);
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget-1',
            name: 'Personal',
            monthlyAmount: 50000,
            remainingAmount: 40000,
            currency: 'INR',
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'food',
            name: 'Food',
            icon: 'restaurant',
            colorHex: '#FF6B6B',
          ),
          mode: InsertMode.insertOrIgnore,
        );

    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'exp-1',
            budgetId: 'budget-1',
            amount: 1000,
            categoryId: 'food',
            note: Value('Lunch'),
            date: now,
            time: Value(now),
            tags: Value('["meal"]'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await database
        .into(database.settings)
        .insert(SettingsCompanion.insert(key: 'themeMode', value: 'dark'));
  }

  group('BackupService', () {
    test('buildBackupPayload collects all data', () async {
      await seedData();

      final payload = await backupService.buildBackupPayload();

      expect(payload['type'], 'monivo_backup');

      final metadata = payload['metadata'] as Map<String, Object?>;
      expect(metadata['schemaVersion'], database.schemaVersion);

      final data = payload['data'] as Map<String, Object?>;
      final budgets = data['budgets'] as List;
      final expenses = data['expenses'] as List;
      final settings = data['settings'] as Map;

      expect(budgets.any((b) => (b as Map)['id'] == 'budget-1'), isTrue);
      expect(expenses.any((e) => (e as Map)['id'] == 'exp-1'), isTrue);
      expect(settings['themeMode'], 'dark');
    });

    test('restore rejects a backup with a newer schema version', () async {
      final file = File('${Directory.systemTemp.path}/bad_backup.json');
      await file.writeAsString(
        '{"type":"monivo_backup","metadata":{"schemaVersion":99},'
        '"data":{"budgets":[],"categories":[],"expenses":[],"settings":{}}}',
      );

      expect(() => backupService.restore(file.path), throwsFormatException);
    });

    test('restore handles a corrupted backup file', () async {
      final file = File('${Directory.systemTemp.path}/corrupt.json');
      await file.writeAsString('not valid json {');

      expect(() => backupService.restore(file.path), throwsFormatException);
    });

    test('restore rejects a file that is not a backup', () async {
      final file = File('${Directory.systemTemp.path}/other.json');
      await file.writeAsString('{"type":"other","data":{}}');

      expect(() => backupService.restore(file.path), throwsFormatException);
    });

    test('restore applies data from a valid backup', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 2, 'appVersion': '1.0.0'},
        'data': {
          'budgets': [
            {
              'id': 'restored-budget',
              'name': 'Trip',
              'monthlyAmount': 1000,
              'remainingAmount': 900,
              'currency': 'USD',
              'startDate': DateTime(2024, 2, 1).toIso8601String(),
              'endDate': DateTime(2024, 2, 29).toIso8601String(),
              'isArchived': false,
              'createdAt': DateTime(2024, 2, 1).toIso8601String(),
              'updatedAt': DateTime(2024, 2, 1).toIso8601String(),
            },
          ],
          'categories': [
            {
              'id': 'food',
              'name': 'Food',
              'icon': 'restaurant',
              'colorHex': '#FF0000',
              'isSystem': true,
            },
          ],
          'expenses': <Object?>[],
          'settings': {'themeMode': 'light'},
        },
      };

      final file = File('${Directory.systemTemp.path}/valid_backup.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );

      final metadata = await backupService.restore(file.path);

      expect(metadata.schemaVersion, 2);
      expect(metadata.appVersion, '1.0.0');

      final budgets = await (database.select(database.budgets)).get();
      expect(budgets.length, 1);
      expect(budgets.first.id, 'restored-budget');

      final settings = await (database.select(database.settings)).get();
      expect(settings, hasLength(1));
      expect(settings.first.value, 'light');
    });
  });

  group('BackupService round trip', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_round_trip_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<void> backUpAndRestore() async {
      final file = File('${tempDir.path}/backup.json');
      await file.writeAsString(
        jsonEncode(await backupService.buildBackupPayload()),
      );
      await backupService.restore(file.path);
    }

    test('a tagged expense restores with its tags', () async {
      await seedData();

      await backUpAndRestore();

      final expense = await database.select(database.expenses).getSingle();
      expect(ExpenseModel.decodeTags(expense.tags), ['meal']);
    });

    test('an untagged expense restores without tags', () async {
      await seedData();
      await database
          .update(database.expenses)
          .write(const ExpensesCompanion(tags: Value(null)));

      await backUpAndRestore();

      final expense = await database.select(database.expenses).getSingle();
      expect(expense.tags, isNull);
    });

    test('an archived category stays archived', () async {
      await seedData();
      await (database.update(database.categories)
            ..where((c) => c.id.equals('food')))
          .write(const CategoriesCompanion(isArchived: Value(true)));

      await backUpAndRestore();

      final food = await (database.select(
        database.categories,
      )..where((c) => c.id.equals('food'))).getSingle();
      expect(food.isArchived, isTrue);
    });
  });

  group('BackupService schema v8 fields', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_v8_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<String> writePayload(Map<String, Object?> payload) async {
      final file = File('${tempDir.path}/backup.json');
      await file.writeAsString(jsonEncode(payload));
      return file.path;
    }

    Map<String, Object?> budgetJson(String id, {Map<String, Object?>? extra}) {
      return {
        'id': id,
        'name': 'Home',
        'monthlyAmount': 500,
        'remainingAmount': 500,
        'currency': 'OMR',
        'startDate': DateTime(2026, 8, 1).toIso8601String(),
        'endDate': DateTime(2026, 8, 31).toIso8601String(),
        'createdAt': DateTime(2026, 8, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 1).toIso8601String(),
        ...?extra,
      };
    }

    Map<String, Object?> billJson(String id, {Object? budgetId}) {
      return {
        'id': id,
        'title': 'Rent',
        'amount': 200,
        'currency': 'OMR',
        'category': 'rent',
        'dueDate': DateTime(2026, 8, 20).toIso8601String(),
        'createdAt': DateTime(2026, 8, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 1).toIso8601String(),
        'budgetId': budgetId,
      };
    }

    Map<String, Object?> backupOf(Map<String, Object?> data) => {
      'type': 'monivo_backup',
      'metadata': {'schemaVersion': 8, 'appVersion': '1.3.0'},
      'data': data,
    };

    test('round-trips reserve, savings goal, bill link and bill_id', () async {
      final day = DateTime(2026, 8, 20, 9);
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'b1',
              name: 'Home',
              monthlyAmount: 500,
              remainingAmount: 300,
              currency: 'OMR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
              createdAt: Value(day),
              updatedAt: Value(day),
              reservedAmount: const Value(50.125),
              savingsTarget: const Value(100),
            ),
          );
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'b2',
              name: 'Trip',
              monthlyAmount: 80,
              remainingAmount: 80,
              currency: 'OMR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
              createdAt: Value(day),
              updatedAt: Value(day),
            ),
          );
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'bill-1',
              title: 'Rent',
              amount: 200,
              currency: 'OMR',
              category: 'rent',
              dueDate: DateTime(2026, 8, 20),
              createdAt: Value(day),
              updatedAt: Value(day),
              budgetId: const Value('b1'),
            ),
          );
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'e-bill',
              budgetId: 'b1',
              amount: 200,
              categoryId: 'bills',
              date: day,
              time: Value(day),
              createdAt: Value(day),
              updatedAt: Value(day),
              billId: const Value('bill-1'),
            ),
          );

      final payload = await backupService.buildBackupPayload();
      final data = payload['data'] as Map<String, Object?>;
      expect((data['bills'] as List).single, containsPair('budgetId', 'b1'));
      expect(
        (data['expenses'] as List).single,
        containsPair('billId', 'bill-1'),
      );

      // Change everything, then restore the snapshot over it.
      await (database.update(database.budgets)..where((b) => b.id.equals('b1')))
          .write(const BudgetsCompanion(reservedAmount: Value(null)));
      await (database.update(database.bills)
            ..where((b) => b.id.equals('bill-1')))
          .write(const BillsCompanion(budgetId: Value('b2')));
      await backupService.restore(await writePayload(payload));

      final budgets = {
        for (final b in await database.select(database.budgets).get()) b.id: b,
      };
      expect(budgets['b1']!.reservedAmount, 50.125);
      expect(budgets['b1']!.savingsTarget, 100);
      expect(budgets['b2']!.reservedAmount, isNull);
      expect(budgets['b2']!.savingsTarget, isNull);
      expect(
        (await database.select(database.bills).getSingle()).budgetId,
        'b1',
      );
      expect(
        (await database.select(database.expenses).getSingle()).billId,
        'bill-1',
      );
    });

    test(
      'an older backup without the new keys restores them as unset',
      () async {
        final path = await writePayload(
          backupOf({
            'budgets': [budgetJson('b1')],
            'bills': [billJson('bill-1')..remove('budgetId')],
          }),
        );

        await backupService.restore(path);

        final budget = await database.select(database.budgets).getSingle();
        expect(budget.reservedAmount, isNull);
        expect(budget.savingsTarget, isNull);
        expect(
          (await database.select(database.bills).getSingle()).budgetId,
          isNull,
        );
      },
    );

    test('integer JSON amounts restore as doubles', () async {
      final path = await writePayload(
        backupOf({
          'budgets': [
            budgetJson('b1', extra: {'reservedAmount': 50, 'savingsTarget': 0}),
          ],
        }),
      );

      await backupService.restore(path);

      final budget = await database.select(database.budgets).getSingle();
      expect(budget.reservedAmount, 50.0);
      expect(budget.savingsTarget, 0.0);
    });

    test(
      'a bill linked to a budget missing from the backup is restored unlinked',
      () async {
        final path = await writePayload(
          backupOf({
            'budgets': [budgetJson('b1')],
            'bills': [
              billJson('bill-ok', budgetId: 'b1'),
              billJson('bill-dangling', budgetId: 'deleted-budget'),
            ],
            'categories': [
              {
                'id': 'bills',
                'name': 'Bills',
                'icon': 'receipt',
                'colorHex': '#123456',
              },
            ],
            'expenses': [
              {
                'id': 'e1',
                'budgetId': 'b1',
                'amount': 200,
                'categoryId': 'bills',
                'date': DateTime(2026, 8, 20).toIso8601String(),
                'time': DateTime(2026, 8, 20).toIso8601String(),
                'createdAt': DateTime(2026, 8, 20).toIso8601String(),
                'updatedAt': DateTime(2026, 8, 20).toIso8601String(),
                // No foreign key: kept even though the bill is absent.
                'billId': 'deleted-bill',
              },
            ],
          }),
        );

        await backupService.restore(path);

        final bills = {
          for (final b in await database.select(database.bills).get())
            b.id: b.budgetId,
        };
        expect(bills, {'bill-ok': 'b1', 'bill-dangling': null});
        expect(
          (await database.select(database.expenses).getSingle()).billId,
          'deleted-bill',
        );
      },
    );

    test('validation rejects mistyped new fields', () async {
      final path = await writePayload(
        backupOf({
          'budgets': [
            budgetJson('b1', extra: {'reservedAmount': 'fifty'}),
          ],
          'bills': [billJson('bill-1', budgetId: 42)],
          'expenses': [
            {
              'id': 'e1',
              'budgetId': 'b1',
              'amount': 10,
              'categoryId': 'food',
              'date': DateTime(2026, 8, 20).toIso8601String(),
              'billId': 7,
            },
          ],
        }),
      );

      final errors = await backupService.validateBackup(path);
      expect(
        errors.map((e) => e.field),
        containsAll([
          'budgets[0].reservedAmount',
          'bills[0].budgetId',
          'expenses[0].billId',
        ]),
      );
    });
  });

  group('BackupService pay later', () {
    late Directory tempDir;
    late PayLaterRepository payLater;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_pay_later_');
      payLater = PayLaterRepositoryImpl(
        localDataSource: PayLaterLocalDataSourceImpl(database: database),
      );
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// Tab t1 with purchases e1 (5) and e2 (8) and a 10 payment p1,
    /// reconciled: p1 pays e1 in full and 5 of e2.
    Future<void> seedTab(AppDatabase db) async {
      final repo = PayLaterRepositoryImpl(
        localDataSource: PayLaterLocalDataSourceImpl(database: db),
      );
      await seedPayLaterBudget(db);
      await repo.createTab(payLaterTab('t1'));
      for (final (id, amount) in [('e1', 5.0), ('e2', 8.0)]) {
        await addPayLaterExpense(db, payLaterExpense(id, amount: amount));
        await repo.linkExpense(expenseId: id, tabId: 't1');
      }
      await repo.createPayment(
        TabPayment(
          id: 'p1',
          tabId: 't1',
          amount: 10,
          paidDate: DateTime(2026, 11, 2),
          createdAt: payLaterStamp,
          updatedAt: payLaterStamp,
        ),
      );
      await reconcileTabsOn(db).all();
    }

    Future<String> writePayload(Map<String, Object?> payload) async {
      final file = File('${tempDir.path}/backup.json');
      await file.writeAsString(jsonEncode(payload));
      return file.path;
    }

    Future<Map<String, int>> payLaterCounts(AppDatabase db) async => {
      'accounts': (await db.select(db.payLaterAccounts).get()).length,
      'entries': (await db.select(db.payLaterEntries).get()).length,
      'payments': (await db.select(db.payLaterPayments).get()).length,
      'allocations': (await db.select(db.payLaterAllocations).get()).length,
    };

    Future<List<(String, String, double, bool)>> allocations() async => [
      for (final a in await payLater.allocationsOf('t1'))
        (a.paymentId, a.expenseId, a.amount, a.isManual),
    ]..sort((a, b) => '${a.$1}${a.$2}'.compareTo('${b.$1}${b.$2}'));

    test('a backup carries all four pay later tables', () async {
      await seedTab(database);

      final data =
          (await backupService.buildBackupPayload())['data']!
              as Map<String, Object?>;

      expect(
        (data['payLaterAccounts']! as List).single,
        containsPair('id', 't1'),
      );
      expect(data['payLaterEntries'], hasLength(2));
      expect(
        (data['payLaterPayments']! as List).single,
        containsPair('id', 'p1'),
      );
      expect(data['payLaterAllocations'], hasLength(2));
    });

    test('a backup is one snapshot: a write made while it reads lands '
        'wholly after it (T15)', () async {
      await seedTab(database);

      // Started first; the purchase below is written while it reads.
      final backup = backupService.buildBackupPayload();
      final write = database.transaction(() async {
        await addPayLaterExpense(database, payLaterExpense('e3', amount: 2));
        await payLater.linkExpense(expenseId: 'e3', tabId: 't1');
      });
      final data = (await backup)['data']! as Map<String, Object?>;
      await write;

      // Every entry points at an expense in the same file, so the file
      // restores (a half-seen write would break the foreign key).
      final expenseIds = {
        for (final e in data['expenses']! as List)
          (e as Map<String, Object?>)['id'],
      };
      final entries = data['payLaterEntries']! as List;
      expect(entries, hasLength(2));
      for (final entry in entries) {
        expect(
          expenseIds,
          contains((entry as Map<String, Object?>)['expenseId']),
        );
      }
      expect(expenseIds, isNot(contains('e3')));
    });

    test('restoring an older backup leaves pay later empty', () async {
      await seedTab(database);
      final path = await writePayload({
        'type': 'monivo_backup',
        'backupFormatVersion': 2,
        'metadata': {'schemaVersion': 8, 'appVersion': '1.0.0'},
        'data': {
          'budgets': [
            {
              'id': 'old-budget',
              'name': 'Old',
              'monthlyAmount': 100,
              'remainingAmount': 100,
              'currency': 'OMR',
              'startDate': DateTime(2026, 10, 1).toIso8601String(),
              'endDate': DateTime(2026, 10, 31).toIso8601String(),
              'createdAt': DateTime(2026, 10, 1).toIso8601String(),
              'updatedAt': DateTime(2026, 10, 1).toIso8601String(),
            },
          ],
          'categories': <Object?>[],
          'expenses': <Object?>[],
          'settings': <String, Object?>{},
        },
      });

      expect(await backupService.validateBackup(path), isEmpty);
      await backupService.restore(path);

      expect(await payLaterCounts(database), {
        'accounts': 0,
        'entries': 0,
        'payments': 0,
        'allocations': 0,
      });
      expect(
        (await database.select(database.budgets).getSingle()).id,
        'old-budget',
      );
    });

    test('a restore puts every tab back with its payment history', () async {
      await seedTab(database);
      final before = await allocations();
      final path = await writePayload(await backupService.buildBackupPayload());
      // Change everything after the backup: restore must undo it.
      await payLater.deletePayment('p1');
      await payLater.unlinkExpense('e2');

      await backupService.restore(path);

      expect(await payLaterCounts(database), {
        'accounts': 1,
        'entries': 2,
        'payments': 1,
        'allocations': 2,
      });
      expect(await allocations(), before);
      expect(before, [('p1', 'e1', 5.0, false), ('p1', 'e2', 5.0, false)]);
    });

    test('a restore reconciles every tab', () async {
      await seedTab(database);
      final payload = await backupService.buildBackupPayload();
      // A file whose allocations are missing (edited by hand): the restore
      // re-derives them instead of leaving the payment unapplied.
      (payload['data']! as Map<String, Object?>)['payLaterAllocations'] =
          <Object?>[];

      await backupService.restore(await writePayload(payload));

      expect(await allocations(), [
        ('p1', 'e1', 5.0, false),
        ('p1', 'e2', 5.0, false),
      ]);
    });

    test('a failed reconcile rolls the whole restore back', () async {
      await seedTab(database);
      final path = await writePayload({
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 8, 'appVersion': '1.0.0'},
        'data': {'budgets': <Object?>[], 'expenses': <Object?>[]},
      });
      final failing = BackupService(
        database: database,
        reconcileTabs: _ThrowingReconcileTabUseCase(),
      );

      await expectLater(failing.restore(path), throwsStateError);

      expect(await payLaterCounts(database), {
        'accounts': 1,
        'entries': 2,
        'payments': 1,
        'allocations': 2,
      });
      expect(await database.select(database.expenses).get(), hasLength(2));
    });

    test('export and import ignore pay later tables', () async {
      await seedTab(database);

      // The data export carries no tab data.
      final export = await ExportService(database: database).collectJsonData();
      expect(
        export.keys.where((k) => k.toLowerCase().contains('paylater')),
        isEmpty,
      );

      // Importing a full backup brings its expenses in as ordinary
      // expenses: no tab, payment or allocation is written.
      final backupPath = await writePayload(
        await backupService.buildBackupPayload(),
      );
      final target = await createInMemoryDatabase();
      addTearDown(target.close);
      await ImportService(database: target).importJson(backupPath);
      expect(await target.select(target.expenses).get(), hasLength(2));
      expect(await payLaterCounts(target), {
        'accounts': 0,
        'entries': 0,
        'payments': 0,
        'allocations': 0,
      });

      // Importing over a database with tabs leaves them as they were.
      final before = await allocations();
      await ImportService(database: database).importJson(backupPath);
      expect(await payLaterCounts(database), {
        'accounts': 1,
        'entries': 2,
        'payments': 1,
        'allocations': 2,
      });
      expect(await allocations(), before);
    });
  });
}

/// Fails every restore reconcile, as a database error mid-restore would.
class _ThrowingReconcileTabUseCase extends FakeReconcileTabUseCase {
  @override
  Future<void> all() async {
    await super.all();
    throw StateError('reconcile failed');
  }
}
