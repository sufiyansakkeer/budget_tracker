import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:monivo/features/expenses/data/models/expense_model.dart';
import 'package:monivo/features/settings/domain/entities/import_report.dart';
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

        final report = await importService.importCsv(file.path);

        expect(report.imported, 2);
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

        final report = await importService.importCsv(file.path);

        expect(report.imported, 2);
        // UX-008: the skipped rows are counted, not dropped silently.
        expect(report.unreadable, 2);
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
        final report = await importService.importCsv(file.path);

        expect(report.imported, 1);
        final imported = await (database.select(database.expenses)).get();
        // The exported id is kept, so a later re-import recognises it.
        expect(imported.single.id, 'exp-1');
        expect(imported.single.amount, 1250.5);
        expect(imported.single.categoryId, 'food');
        expect(imported.single.budgetId, 'budget-1');
        expect(imported.single.note, 'Lunch, with a comma');
        // Comma-separated tags are stored as the JSON list the app reads;
        // kept as plain text they never showed in the app.
        expect(ExpenseModel.decodeTags(imported.single.tags), ['work', 'team']);
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

          final report = await importService.importCsv(file.path);

          expect(report.imported, 3);
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

      Future<void> seedBudget(String id, String currency) => database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: id,
              name: 'Budget $id',
              monthlyAmount: 50000,
              remainingAmount: 50000,
              currency: currency,
              startDate: DateTime(2024, 1, 1),
              endDate: DateTime(2024, 1, 31),
            ),
          );

      test('UX-008: importing the same Monivo export twice adds nothing the '
          'second time, and says why', () async {
        await seedBudget('budget-1', 'INR');
        await database
            .into(database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-1',
                budgetId: 'budget-1',
                amount: 300,
                categoryId: 'food',
                date: DateTime(2024, 1, 10),
              ),
            );
        final rows = await ExportService(database: database).collectCsvRows();
        final file = File('${Directory.systemTemp.path}/twice.csv');
        await file.writeAsString(const ListToCsvConverter().convert(rows));

        final report = await importService.importCsv(file.path);

        expect(report, const ImportReport(duplicates: 1));
        final expenses = await (database.select(database.expenses)).get();
        expect(expenses, hasLength(1), reason: 'never doubled');
      });

      test('UX-008: the same id twice in one file is added once', () async {
        await seedBudget('budget-1', 'INR');
        final file = File('${Directory.systemTemp.path}/dupe_rows.csv');
        await file.writeAsString(
          'id,amount,categoryId,date,budgetId\n'
          'r1,100,food,2024-01-10,budget-1\n'
          'r1,100,food,2024-01-10,budget-1\n',
        );

        final report = await importService.importCsv(file.path);

        expect(report, const ImportReport(imported: 1, duplicates: 1));
      });

      test('UX-008: a row whose currency differs from its budget is skipped, '
          'never moved into another currency', () async {
        await seedBudget('budget-1', 'INR');
        final file = File('${Directory.systemTemp.path}/currency.csv');
        await file.writeAsString(
          'amount,currency,categoryId,date,budgetId\n'
          '100,INR,food,2024-01-10,budget-1\n'
          '4.5,OMR,food,2024-01-11,budget-1\n',
        );

        final report = await importService.importCsv(file.path);

        expect(report, const ImportReport(imported: 1, otherCurrency: 1));
        final expenses = await (database.select(database.expenses)).get();
        expect(expenses.single.amount, 100);
      });

      test(
        'UX-008: a row naming no budget goes to a budget in its currency',
        () async {
          await seedBudget('inr', 'INR');
          await seedBudget('omr', 'OMR');
          final file = File('${Directory.systemTemp.path}/orphan.csv');
          await file.writeAsString(
            'amount,currency,categoryId,date\n'
            '4.5,OMR,food,2024-01-11\n'
            '9,USD,food,2024-01-11\n',
          );

          final report = await importService.importCsv(file.path);

          expect(report, const ImportReport(imported: 1, otherCurrency: 1));
          final expenses = await (database.select(database.expenses)).get();
          expect(expenses.single.budgetId, 'omr');
        },
      );

      test('UX-008: with no budget yet, rows in a second currency are '
          'skipped, not put in the budget made for the first', () async {
        final file = File('${Directory.systemTemp.path}/no_budgets.csv');
        await file.writeAsString(
          'amount,currency,categoryId,date\n'
          '4.5,OMR,food,2024-01-11\n'
          '100,INR,food,2024-01-12\n',
        );

        final report = await importService.importCsv(file.path);

        expect(report, const ImportReport(imported: 1, otherCurrency: 1));
        final budgets = await (database.select(database.budgets)).get();
        expect(budgets.single.currency, 'OMR');
      });

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

        final report = await importService.importJson(file.path);

        expect(report, const ImportReport());
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

      group('schema v8 fields', () {
        late Directory tempDir;

        setUp(() async {
          tempDir = Directory.systemTemp.createTempSync('import_v8_');
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
                  reservedAmount: const Value(50),
                  savingsTarget: const Value(25.5),
                ),
              );
          await database
              .into(database.expenses)
              .insert(
                ExpensesCompanion.insert(
                  id: 'e1',
                  budgetId: 'b1',
                  amount: 200,
                  categoryId: 'bills',
                  date: day,
                  time: Value(day),
                  billId: const Value('bill-1'),
                ),
              );
        });

        tearDown(() => tempDir.deleteSync(recursive: true));

        Map<String, Object?> budgetJson(Map<String, Object?> extra) => {
          'id': 'b1',
          'name': 'Home renamed',
          'monthlyAmount': 600,
          'remainingAmount': 400,
          'currency': 'OMR',
          'startDate': DateTime(2026, 8, 1).toIso8601String(),
          'endDate': DateTime(2026, 8, 31).toIso8601String(),
          'createdAt': DateTime(2026, 8, 1).toIso8601String(),
          'updatedAt': DateTime(2026, 8, 2).toIso8601String(),
          ...extra,
        };

        Map<String, Object?> expenseJson(Map<String, Object?> extra) => {
          'id': 'e1',
          'budgetId': 'b1',
          'amount': 210,
          'categoryId': 'bills',
          'date': DateTime(2026, 8, 20, 9).toIso8601String(),
          'time': DateTime(2026, 8, 20, 9).toIso8601String(),
          'createdAt': DateTime(2026, 8, 20).toIso8601String(),
          'updatedAt': DateTime(2026, 8, 21).toIso8601String(),
          ...extra,
        };

        Future<void> importPayload(Map<String, Object?> payload) async {
          final file = File('${tempDir.path}/data.json');
          await file.writeAsString(jsonEncode(payload));
          await importService.importJson(file.path);
        }

        test(
          'an older export without the keys keeps the stored values',
          () async {
            await importPayload({
              'budgets': [budgetJson({})],
              'expenses': [expenseJson({})],
            });

            final budget = await database.select(database.budgets).getSingle();
            expect(budget.name, 'Home renamed');
            expect(budget.monthlyAmount, 600);
            expect(budget.reservedAmount, 50);
            expect(budget.savingsTarget, 25.5);
            final expense = await database
                .select(database.expenses)
                .getSingle();
            expect(expense.amount, 210);
            expect(expense.billId, 'bill-1');
          },
        );

        test('present keys overwrite, including an explicit null', () async {
          await importPayload({
            'budgets': [
              budgetJson({'reservedAmount': 75, 'savingsTarget': null}),
            ],
            'expenses': [
              expenseJson({'billId': null}),
            ],
          });

          final budget = await database.select(database.budgets).getSingle();
          expect(budget.reservedAmount, 75.0);
          expect(budget.savingsTarget, isNull);
          expect(
            (await database.select(database.expenses).getSingle()).billId,
            isNull,
          );
        });

        test(
          'round-trips through ExportService into an empty database',
          () async {
            final exported = await ExportService(
              database: database,
            ).collectJsonData();
            final target = await createInMemoryDatabase();
            addTearDown(target.close);

            final file = File('${tempDir.path}/export.json');
            await file.writeAsString(jsonEncode(exported));
            await ImportService(database: target).importJson(file.path);

            final budget = await target.select(target.budgets).getSingle();
            expect(budget.reservedAmount, 50);
            expect(budget.savingsTarget, 25.5);
            expect(
              (await target.select(target.expenses).getSingle()).billId,
              'bill-1',
            );
          },
        );
      });

      group('UX-009: tags', () {
        Map<String, Object?> payloadWithTags(Object? tags) => {
          'budgets': [
            {
              'id': 'budget-x',
              'name': 'Personal',
              'monthlyAmount': 5000,
              'remainingAmount': 5000,
              'currency': 'INR',
              'startDate': DateTime(2024, 1, 1).toIso8601String(),
              'endDate': DateTime(2024, 1, 31).toIso8601String(),
              'createdAt': DateTime(2024, 1, 1).toIso8601String(),
              'updatedAt': DateTime(2024, 1, 1).toIso8601String(),
            },
          ],
          'expenses': [
            {
              'id': 'tagged',
              'budgetId': 'budget-x',
              'amount': 250,
              'categoryId': 'food',
              'date': DateTime(2024, 1, 10).toIso8601String(),
              'time': DateTime(2024, 1, 10, 13).toIso8601String(),
              'tags': tags,
              'createdAt': DateTime(2024, 1, 10).toIso8601String(),
              'updatedAt': DateTime(2024, 1, 10).toIso8601String(),
            },
          ],
        };

        Future<List<String>> importAndReadTags(Object? tags) async {
          final file = File('${Directory.systemTemp.path}/tags.json');
          await file.writeAsString(jsonEncode(payloadWithTags(tags)));
          await importService.importJson(file.path);
          final row = await (database.select(
            database.expenses,
          )..where((e) => e.id.equals('tagged'))).getSingle();
          return ExpenseModel.decodeTags(row.tags);
        }

        test('a Monivo export round-trips its tagged expenses', () async {
          await seedTagged(database);
          final data = await ExportService(
            database: database,
          ).collectJsonData();
          await (database.delete(database.expenses)).go();
          final file = File('${Directory.systemTemp.path}/round_trip.json');
          await file.writeAsString(jsonEncode(data));

          final report = await importService.importJson(file.path);

          expect(report.imported, 1);
          final row = await (database.select(database.expenses)).getSingle();
          expect(ExpenseModel.decodeTags(row.tags), ['work', 'team']);
        });

        test('the stored JSON string (what an export writes)', () async {
          expect(await importAndReadTags('["work","team"]'), ['work', 'team']);
        });

        test('a JSON list', () async {
          expect(await importAndReadTags(['work', 'team']), ['work', 'team']);
        });

        test('comma-separated text', () async {
          expect(await importAndReadTags('work, team'), ['work', 'team']);
        });

        test('none', () async {
          expect(await importAndReadTags(null), isEmpty);
        });

        test(
          'a malformed value is rejected before anything is written',
          () async {
            final file = File('${Directory.systemTemp.path}/bad_tags.json');
            await file.writeAsString(jsonEncode(payloadWithTags(42)));

            await expectLater(
              importService.importJson(file.path),
              throwsFormatException,
            );
            expect(await (database.select(database.expenses)).get(), isEmpty);
            expect(await (database.select(database.budgets)).get(), isEmpty);
          },
        );

        test(
          're-importing the same file updates rather than duplicates',
          () async {
            await importAndReadTags(['a']);
            final file = File('${Directory.systemTemp.path}/tags.json');
            final report = await importService.importJson(file.path);
            expect(report, const ImportReport(updated: 1));
            expect(
              await (database.select(database.expenses)).get(),
              hasLength(1),
            );
          },
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

/// One budget and one expense tagged "work" and "team", stored the way the
/// app stores tags (a JSON list string).
Future<void> seedTagged(AppDatabase database) async {
  await database
      .into(database.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: 'budget-1',
          name: 'Personal',
          monthlyAmount: 50000,
          remainingAmount: 50000,
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
          date: DateTime(2024, 1, 10),
          time: Value(DateTime(2024, 1, 10, 12, 30)),
          tags: Value(ExpenseModel.encodeTags(['work', 'team'])),
        ),
      );
}
