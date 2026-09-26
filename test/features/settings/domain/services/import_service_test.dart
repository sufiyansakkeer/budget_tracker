import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:monivo/features/settings/domain/services/export_service.dart';
import 'package:monivo/features/settings/domain/services/import_service.dart';

import '../../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late ImportService importService;

  setUp(() async {
    database = await createInMemoryDatabase();
    importService = ImportService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ImportService', () {
    group('importCsv', () {
      test('imports valid CSV rows', () async {
        final file = File('${Directory.systemTemp.path}/import.csv');
        await file.writeAsString(
          'amount,categoryId,note,date,tags\n'
          '100.0,food,Lunch,2024-01-10,meal\n'
          '250.0,grocery,Weekly,2024-01-11,\n',
        );

        final count = await importService.importCsv(file.path);

        expect(count, 2);
        final expenses = await (database.select(database.expenses)).get();
        expect(expenses.length, 2);
        expect(expenses.first.amount, 100.0);
      });

      test('skips invalid rows and keeps valid ones', () async {
        final file = File('${Directory.systemTemp.path}/import_partial.csv');
        await file.writeAsString(
          'amount,categoryId,note,date,tags\n'
          '100.0,food,Valid,2024-01-10,meal\n'
          'not-a-number,food,Invalid,2024-01-11,\n'
          '-5.0,food,Negative,2024-01-12,\n'
          '200.0,food,Valid2,2024-01-13,\n',
        );

        final count = await importService.importCsv(file.path);

        expect(count, 2);
        final expenses = await (database.select(database.expenses)).get();
        expect(expenses.length, 2);
      });

      test('re-imports the file produced by ExportService', () async {
        // Seed one budget + expense, export, wipe expenses, import again.
        final now = DateTime(2024, 1, 10, 12, 30);
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
              ),
            );
        await database
            .into(database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-1',
                budgetId: 'budget-1',
                amount: 1250.5,
                categoryId: 'food',
                note: const Value('Lunch, with a comma'),
                date: DateTime(2024, 1, 10),
                time: Value(now),
                tags: const Value('work,team'),
              ),
            );
        final rows = await ExportService(database: database).collectCsvRows();
        final csv = const ListToCsvConverter().convert(rows);
        await (database.delete(database.expenses)).go();

        final file = File('${Directory.systemTemp.path}/round_trip.csv');
        await file.writeAsString(csv);
        final count = await importService.importCsv(file.path);

        expect(count, 1);
        final imported = await (database.select(database.expenses)).get();
        expect(imported.single.amount, 1250.5);
        expect(imported.single.categoryId, 'food');
        expect(imported.single.budgetId, 'budget-1');
        expect(imported.single.note, 'Lunch, with a comma');
        expect(imported.single.tags, 'work,team');
        expect(imported.single.date, DateTime(2024, 1, 10));
        expect(imported.single.time, now);
      });

      test(
        'matches columns by header name and maps unknown categories',
        () async {
          final file = File('${Directory.systemTemp.path}/import_headers.csv');
          await file.writeAsString(
            'Date,Note,Category,Amount\n'
            '2024-02-01,Groceries,grocery,45.5\n'
            '2024-02-02,Cinema,Entertainment,12\n'
            '2024-02-03,Mystery,no-such-category,7\n',
          );

          final count = await importService.importCsv(file.path);

          expect(count, 3);
          final expenses = await (database.select(database.expenses)).get();
          final byNote = {for (final e in expenses) e.note: e};
          expect(byNote['Groceries']!.categoryId, 'grocery');
          expect(
            byNote['Cinema']!.categoryId,
            'entertainment',
            reason: 'matched by category name, case-insensitive',
          );
          expect(byNote['Mystery']!.categoryId, fallbackCategoryId);
        },
      );

      test('rejects a missing file', () async {
        expect(
          () => importService.importCsv('/nonexistent/file.csv'),
          throwsFormatException,
        );
      });

      test('rejects an empty CSV', () async {
        final file = File('${Directory.systemTemp.path}/empty.csv');
        await file.writeAsString('amount,categoryId,note,date,tags\n');

        expect(() => importService.importCsv(file.path), throwsFormatException);
      });
    });

    group('importJson', () {
      test('imports a data-only JSON payload', () async {
        final payload = {
          'budgets': [
            {
              'id': 'budget-x',
              'name': 'Personal',
              'monthlyAmount': 5000,
              'remainingAmount': 4000,
              'currency': 'INR',
              'startDate': DateTime(2024, 1, 1).toIso8601String(),
              'endDate': DateTime(2024, 1, 31).toIso8601String(),
              'isArchived': false,
              'createdAt': DateTime(2024, 1, 1).toIso8601String(),
              'updatedAt': DateTime(2024, 1, 1).toIso8601String(),
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
        };
        final file = File('${Directory.systemTemp.path}/data.json');
        await file.writeAsString(jsonEncode(payload));

        final schema = await importService.importJson(file.path);

        expect(schema, 0);
        final budgets = await (database.select(database.budgets)).get();
        expect(budgets.length, 1);
        expect(budgets.first.id, 'budget-x');

        final categories = await (database.select(database.categories)).get();
        // Defaults are seeded by the database; the imported 'food' row
        // replaces the seeded one instead of duplicating it.
        expect(categories.length, defaultCategoryRows.length);
        expect(
          categories.firstWhere((c) => c.id == 'food').colorHex,
          '#FF0000',
        );
      });

      test('rejects JSON with a newer schema version', () async {
        final payload = {
          'metadata': {'schemaVersion': 99},
          'data': {
            'budgets': <Object?>[],
            'categories': <Object?>[],
            'expenses': <Object?>[],
          },
        };
        final file = File('${Directory.systemTemp.path}/newer.json');
        await file.writeAsString(jsonEncode(payload));

        expect(
          () => importService.importJson(file.path),
          throwsFormatException,
        );
      });

      test('rejects corrupted JSON', () async {
        final file = File('${Directory.systemTemp.path}/corrupt.json');
        await file.writeAsString('{invalid}');

        expect(
          () => importService.importJson(file.path),
          throwsFormatException,
        );
      });
    });
  });
}
