import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Opens a raw SQLite database shaped exactly like schema v4 (captured in
/// `test/fixtures/schema_v4.sql`), lets the caller seed legacy data, then
/// hands it to [AppDatabase] so the real `onUpgrade` and `beforeOpen` run.
Future<AppDatabase> openUpgradedFromV4(
  void Function(sqlite.Database raw) seed,
) async {
  final raw = sqlite.sqlite3.openInMemory();
  final schema = File('test/fixtures/schema_v4.sql').readAsStringSync();
  raw.execute(schema);
  raw.execute('PRAGMA user_version = 4');
  seed(raw);
  final db = AppDatabase(executor: NativeDatabase.opened(raw));
  // Any query forces Drift to open the connection and run migrations.
  await db.customSelect('SELECT 1').get();
  return db;
}

void main() {
  const seconds = 1000; // unix seconds are what Drift stores for DateTime

  group('schema v4 → v5 migration', () {
    late AppDatabase db;

    setUp(() async {
      db = await openUpgradedFromV4((raw) {
        raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, start_date, end_date, is_archived, created_at, updated_at)
          VALUES ('archived', 'Old', 100, 100, 'INR', 1, 2, 1, 1, 1),
                 ('live', 'Live', 1000, 1000, 'INR', 10, 40, 0, 1, 1);
        ''');
        // Only two categories existed; 'food' is missing entirely.
        raw.execute('''
          INSERT INTO categories (id, name, icon, color_hex, is_system)
          VALUES ('bills', 'Bills', 'receipt_long', '#EE5253', 1),
                 ('others', 'Others', 'help_outline', '#8395A7', 1);
        ''');
        raw.execute('''
          INSERT INTO expenses (id, budget_id, amount, category_id, date, time,
            created_at, updated_at)
          VALUES ('ok', 'live', 10, 'bills', 20, 20, 1, 1),
                 ('orphan-budget', 'ghost', 20, 'bills', 20, 20, 1, 1),
                 ('orphan-category', 'live', 30, 'unknown', 20, 20, 1, 1);
        ''');
      });
    });

    tearDown(() => db.close());

    test('sets the user version to 5', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data['user_version'], 5);
    });

    test('enables foreign key enforcement for the connection', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data['foreign_keys'], 1);

      await expectLater(
        db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'bad',
                budgetId: 'does-not-exist',
                amount: 1,
                categoryId: 'bills',
                date: DateTime(2026, 9, 1),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('creates the composite (budget_id, date) index', () async {
      final rows = await db.customSelect("PRAGMA index_list('expenses')").get();
      final names = rows.map((r) => r.data['name']).toSet();
      expect(
        names,
        containsAll([
          'index_expenses_date',
          'index_expenses_category',
          'index_expenses_budget',
          'index_expenses_budget_date',
        ]),
      );
      final cols = await db
          .customSelect("PRAGMA index_info('index_expenses_budget_date')")
          .get();
      expect(cols.map((r) => r.data['name']).toList(), ['budget_id', 'date']);
    });

    test('seeds the missing default categories', () async {
      final rows = await db.select(db.categories).get();
      expect(rows.length, defaultCategoryRows.length);
      expect(rows.any((c) => c.id == 'food'), isTrue);
      // Existing rows are kept as they were.
      expect(rows.firstWhere((c) => c.id == 'bills').name, 'Bills');
    });

    test(
      'repairs expenses that point at a missing budget or category',
      () async {
        final orphanBudget = await (db.select(
          db.expenses,
        )..where((e) => e.id.equals('orphan-budget'))).getSingle();
        expect(
          orphanBudget.budgetId,
          'live',
          reason: 'moved to the newest non-archived budget',
        );

        final orphanCategory = await (db.select(
          db.expenses,
        )..where((e) => e.id.equals('orphan-category'))).getSingle();
        expect(orphanCategory.categoryId, fallbackCategoryId);

        final ok = await (db.select(
          db.expenses,
        )..where((e) => e.id.equals('ok'))).getSingle();
        expect(ok.budgetId, 'live');
        expect(ok.categoryId, 'bills');
      },
    );

    test('keeps legacy data intact', () async {
      final budgets = await db.select(db.budgets).get();
      expect(budgets.length, 2);
      final live = budgets.firstWhere((b) => b.id == 'live');
      expect(live.monthlyAmount, 1000);
      expect(
        live.startDate,
        DateTime.fromMillisecondsSinceEpoch(10 * seconds, isUtc: false),
      );
    });
  });

  group('legacy camelCase columns from the old v3 migration', () {
    test('are healed into snake_case columns', () async {
      final db = await openUpgradedFromV4((raw) {
        // Simulate a database whose v3 migration added camelCase twins and
        // never received the snake_case columns Drift reads.
        raw.execute('ALTER TABLE budgets DROP COLUMN start_date');
        raw.execute('ALTER TABLE budgets DROP COLUMN end_date');
        raw.execute('ALTER TABLE budgets ADD COLUMN startDate INTEGER');
        raw.execute('ALTER TABLE budgets ADD COLUMN endDate INTEGER');
        raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, startDate, endDate, is_archived, created_at, updated_at)
          VALUES ('legacy', 'Legacy', 500, 500, 'INR', 100, 200, 0, 1, 1);
        ''');
      });
      addTearDown(db.close);

      final budget = await db.select(db.budgets).getSingle();
      expect(budget.startDate.millisecondsSinceEpoch, 100 * seconds);
      expect(budget.endDate.millisecondsSinceEpoch, 200 * seconds);
    });
  });

  group('fresh database', () {
    test('seeds default categories and enforces foreign keys', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final categories = await db.select(db.categories).get();
      expect(categories.length, defaultCategoryRows.length);
      final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fk.data['foreign_keys'], 1);
    });
  });
}
