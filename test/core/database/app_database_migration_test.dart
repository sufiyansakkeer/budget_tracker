import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/data/models/budget_model.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Opens a raw SQLite database shaped exactly like the schema captured in
/// `test/fixtures/<fixture>`, stamps it with [version], lets the caller seed
/// legacy data, then hands it to [AppDatabase] so the real `onUpgrade` and
/// `beforeOpen` run.
Future<AppDatabase> openUpgradedFrom(
  String fixture,
  int version,
  void Function(sqlite.Database raw) seed,
) async {
  final raw = sqlite.sqlite3.openInMemory();
  final schema = File('test/fixtures/$fixture').readAsStringSync();
  raw.execute(schema);
  raw.execute('PRAGMA user_version = $version');
  seed(raw);
  final db = AppDatabase(executor: NativeDatabase.opened(raw));
  // Any query forces Drift to open the connection and run migrations.
  await db.customSelect('SELECT 1').get();
  return db;
}

/// Schema v4: what every 1.x release shipped.
Future<AppDatabase> openUpgradedFromV4(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v4.sql', 4, seed);

/// Schema v5 as the first v5 build created it: `categories.is_archived` was
/// added to the table definition afterwards without a version bump.
Future<AppDatabase> openUpgradedFromFirstV5(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v5_pre_category_archive.sql', 5, seed);

/// Every table's column set plus the index names, for comparing a migrated
/// database against a freshly created one.
Future<Map<String, Set<String>>> schemaOf(AppDatabase db) async {
  final result = <String, Set<String>>{};
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  for (final table in tables) {
    final name = table.data['name'] as String;
    final columns = await db.customSelect('PRAGMA table_info($name)').get();
    result[name] = columns.map((c) => c.data['name'] as String).toSet();
  }
  final indexes = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  result['<indexes>'] = indexes.map((r) => r.data['name'] as String).toSet();
  return result;
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

    test('sets the user version to the current schema version', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data['user_version'], db.schemaVersion);
    });

    test('adds categories.is_archived, defaulting to false', () async {
      final rows = await db.select(db.categories).get();
      expect(rows, isNotEmpty);
      expect(rows.every((c) => !c.isArchived), isTrue);
    });

    test(
      'derives local-midnight dates for pre-v3 month/year budgets',
      () async {
        final legacy = await openUpgradedFromV4((raw) {
          raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, month, year, start_date, end_date, is_archived,
            created_at, updated_at)
          VALUES ('v2', 'Old', 100, 100, 'INR', 9, 2026, 0, 0, 0, 1, 1);
        ''');
        });
        addTearDown(legacy.close);

        final budget = await legacy.select(legacy.budgets).getSingle();
        expect(budget.startDate, DateTime(2026, 9, 1));
        expect(budget.endDate, DateTime(2026, 9, 30));
      },
    );

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

    test('converts the millisecond timestamps that migration wrote', () async {
      // The released v3 migration stored `strftime('%s', ...) * 1000`.
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 30);
      final db = await openUpgradedFromV4((raw) {
        raw.execute('ALTER TABLE budgets DROP COLUMN start_date');
        raw.execute('ALTER TABLE budgets DROP COLUMN end_date');
        raw.execute('ALTER TABLE budgets ADD COLUMN startDate INTEGER');
        raw.execute('ALTER TABLE budgets ADD COLUMN endDate INTEGER');
        raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, startDate, endDate, is_archived, created_at, updated_at)
          VALUES ('legacy', 'Legacy', 500, 500, 'INR',
            ${start.millisecondsSinceEpoch}, ${end.millisecondsSinceEpoch},
            0, 1, 1);
        ''');
      });
      addTearDown(db.close);

      final budget = await db.select(db.budgets).getSingle();
      expect(budget.startDate, start);
      expect(budget.endDate, end);
      expect(
        BudgetModel.toEntity(budget).isActiveOn(DateTime(2026, 9, 15)),
        isTrue,
      );
    });
  });

  group('first v5 build → current (categories without is_archived)', () {
    late AppDatabase db;

    setUp(() async {
      db = await openUpgradedFromFirstV5((raw) {
        raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, start_date, end_date, is_archived, created_at, updated_at)
          VALUES ('daily', 'daily', 2100, 1800, 'INR',
                  1789800375, 1792392375, 0, 1789800394, 1789807301),
                 ('new', 'new ly', 3700, 2772, 'INR',
                  1789669800, 1792261800, 0, 1789807079, 1789807079);
        ''');
        raw.execute('''
          INSERT INTO categories (id, name, icon, color_hex, is_system)
          VALUES ('food', 'Food', 'restaurant', '#FF6B6B', 1),
                 ('grocery', 'Grocery', 'shopping_cart', '#4ECDC4', 1),
                 ('custom', 'Coffee', 'coffee', '#123456', 0);
        ''');
        raw.execute('''
          INSERT INTO expenses (id, budget_id, amount, category_id, note,
            date, time, created_at, updated_at)
          VALUES ('e1', 'daily', 300, 'food', NULL,
                  1789756200, 1789803960, 1, 1),
                 ('e2', 'new', 349, 'grocery', 'weekly shop',
                  1789756200, 1789807080, 1, 1),
                 ('e3', 'new', 45, 'custom', NULL,
                  1789756200, 1789814700, 1, 1);
        ''');
      });
    });

    tearDown(() => db.close());

    test('moves the user version past 5', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data['user_version'], db.schemaVersion);
      expect(db.schemaVersion, greaterThan(5));
    });

    test('categories become readable again and are not archived', () async {
      final rows = await db.select(db.categories).get();
      final byId = {for (final c in rows) c.id: c};
      expect(byId['custom']?.name, 'Coffee');
      expect(byId['custom']?.isSystem, isFalse);
      expect(rows.every((c) => !c.isArchived), isTrue);
      // Missing defaults are seeded, existing rows are untouched.
      expect(rows.length, greaterThanOrEqualTo(defaultCategoryRows.length));
      expect(byId['food']?.colorHex, '#FF6B6B');
    });

    test('keeps every expense attached to its budget', () async {
      final expenses = await db.select(db.expenses).get();
      final byId = {for (final e in expenses) e.id: e};
      expect(byId.length, 3);
      expect(byId['e1']?.budgetId, 'daily');
      expect(byId['e2']?.budgetId, 'new');
      expect(byId['e2']?.note, 'weekly shop');
      expect(byId['e2']?.amount, 349);
      expect(byId['e3']?.categoryId, 'custom');
      expect(
        byId['e2']?.date,
        DateTime.fromMillisecondsSinceEpoch(1789756200 * seconds),
      );
    });

    test('keeps budgets exactly as stored', () async {
      final budgets = await db.select(db.budgets).get();
      final newLy = budgets.firstWhere((b) => b.id == 'new');
      expect(newLy.monthlyAmount, 3700);
      expect(newLy.remainingAmount, 2772);
      expect(newLy.currency, 'INR');
      expect(
        newLy.startDate,
        DateTime.fromMillisecondsSinceEpoch(1789669800 * seconds),
      );
    });
  });

  group('schema parity', () {
    // Guards against the bug behind v6: a column added to a table definition
    // without a migration step. Every upgrade path must end with exactly the
    // schema a fresh install gets.
    late Map<String, Set<String>> fresh;

    setUp(() async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      fresh = await schemaOf(db);
    });

    test('upgrading from v4 yields the fresh-install schema', () async {
      final db = await openUpgradedFromV4((_) {});
      addTearDown(db.close);
      expect(await schemaOf(db), fresh);
    });

    test(
      'upgrading from the first v5 build yields the fresh-install schema',
      () async {
        final db = await openUpgradedFromFirstV5((_) {});
        addTearDown(db.close);
        expect(await schemaOf(db), fresh);
      },
    );

    test('the v4 fixture really differs from the current schema', () async {
      // If this fails the fixture was regenerated from the current schema
      // and the parity tests above no longer prove anything.
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v4.sql').readAsStringSync());
      final cols = raw.select('PRAGMA table_info(categories)');
      expect(cols.map((r) => r['name']), isNot(contains('is_archived')));
      raw.dispose();
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
