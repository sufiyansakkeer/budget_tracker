import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

/// Schema v3: before bills existed (v4 without the bills tables), so the
/// upgrade creates `bills` from the current definition.
Future<AppDatabase> openUpgradedFromV3(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v3.sql', 3, seed);

/// Schema v4: what every 1.x release shipped.
Future<AppDatabase> openUpgradedFromV4(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v4.sql', 4, seed);

/// Schema v5 as the first v5 build created it: `categories.is_archived` was
/// added to the table definition afterwards without a version bump.
Future<AppDatabase> openUpgradedFromFirstV5(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v5_pre_category_archive.sql', 5, seed);

/// Schema v6: the last schema before the currency-converter caches.
Future<AppDatabase> openUpgradedFromV6(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v6.sql', 6, seed);

/// Schema v7: the last schema before bills were linked to budgets.
Future<AppDatabase> openUpgradedFromV7(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v7.sql', 7, seed);

/// Schema v8: the last schema before Pay Later.
Future<AppDatabase> openUpgradedFromV8(
  void Function(sqlite.Database raw) seed,
) => openUpgradedFrom('schema_v8.sql', 8, seed);

/// `(table, from, to)` of every foreign key declared on [table].
Future<Set<(String, String, String)>> foreignKeysOf(
  AppDatabase db,
  String table,
) async {
  final rows = await db.customSelect('PRAGMA foreign_key_list($table)').get();
  return {
    for (final r in rows)
      (
        r.data['table'] as String,
        r.data['from'] as String,
        r.data['to'] as String,
      ),
  };
}

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

    test('upgrading from v3 yields the fresh-install schema', () async {
      // `from < 4` creates bills with the current definition (budget_id
      // included); the v8 step must skip that column and still add the index.
      final db = await openUpgradedFromV3((_) {});
      addTearDown(db.close);
      expect(await schemaOf(db), fresh);
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

    test('upgrading from v6 yields the fresh-install schema', () async {
      final db = await openUpgradedFromV6((_) {});
      addTearDown(db.close);
      expect(await schemaOf(db), fresh);
    });

    test('upgrading from v7 yields the fresh-install schema', () async {
      final db = await openUpgradedFromV7((_) {});
      addTearDown(db.close);
      expect(await schemaOf(db), fresh);
    });

    test('upgrading from v8 yields the fresh-install schema', () async {
      final db = await openUpgradedFromV8((_) {});
      addTearDown(db.close);
      expect(await schemaOf(db), fresh);
    });

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

  group('schema v6 → v7 migration (currency converter caches)', () {
    late AppDatabase db;

    setUp(() async {
      db = await openUpgradedFromV6((raw) {
        raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, start_date, end_date, is_archived, created_at, updated_at)
          VALUES ('b1', 'Home', 500, 320.5, 'OMR', 1789669800, 1792261800, 0,
            1, 1);
          INSERT INTO categories (id, name, icon, color_hex, is_system,
            is_archived)
          VALUES ('coffee', 'Coffee', 'coffee', '#123456', 0, 0);
          INSERT INTO expenses (id, budget_id, amount, category_id, note, date,
            time, created_at, updated_at)
          VALUES ('e1', 'b1', 179.5, 'coffee', 'beans', 1789756200,
            1789756200, 1, 1);
          INSERT INTO settings (key, value) VALUES ('currency_code', 'OMR');
        ''');
      });
    });

    tearDown(() => db.close());

    test('moves the user version to the current schema', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data['user_version'], 9);
      expect(db.schemaVersion, 9);
    });

    test('creates the exchange-rate and currency cache tables', () async {
      final tables = (await schemaOf(db));
      expect(tables['exchange_rates'], {
        'id',
        'base_currency',
        'quote_currency',
        'rate',
        'rate_date',
        'fetched_at',
        'provider',
      });
      expect(tables['converter_currencies'], {
        'code',
        'name',
        'symbol',
        'fetched_at',
      });
      expect(await db.select(db.exchangeRates).get(), isEmpty);
    });

    test('keeps every existing row exactly as it was', () async {
      final budget = await db.select(db.budgets).getSingle();
      expect(budget.name, 'Home');
      expect(budget.monthlyAmount, 500);
      expect(budget.remainingAmount, 320.5);
      expect(budget.currency, 'OMR');

      final expense = await db.select(db.expenses).getSingle();
      expect(expense.amount, 179.5);
      expect(expense.note, 'beans');
      expect(expense.categoryId, 'coffee');

      final categories = await db.select(db.categories).get();
      expect(categories.any((c) => c.id == 'coffee' && !c.isSystem), isTrue);

      final setting = await db.select(db.settings).getSingle();
      expect(setting.value, 'OMR');
    });

    test('the new tables accept writes after the upgrade', () async {
      await db
          .into(db.exchangeRates)
          .insert(
            ExchangeRatesCompanion.insert(
              id: 'OMR_INR',
              baseCurrency: 'OMR',
              quoteCurrency: 'INR',
              rate: '249.33',
              rateDate: '2026-09-26',
              fetchedAt: DateTime.utc(2026, 9, 26, 12),
              provider: 'Frankfurter',
            ),
          );
      final row = await db.select(db.exchangeRates).getSingle();
      expect(row.rate, '249.33');
    });

    test('the v6 fixture really lacks the converter tables', () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v6.sql').readAsStringSync());
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'])
          .toSet();
      expect(tables, isNot(contains('exchange_rates')));
      expect(tables, contains('categories'));
      raw.dispose();
    });
  });

  group('schema v7 → v8 migration (safe-to-spend links)', () {
    late AppDatabase db;

    setUp(() async {
      db = await openUpgradedFromV7((raw) {
        raw.execute('''
          INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
            currency, start_date, end_date, is_archived, created_at, updated_at)
          VALUES ('b1', 'Home', 500, 320.5, 'OMR', 1789669800, 1792261800, 0,
            1, 1);
          INSERT INTO categories (id, name, icon, color_hex, is_system,
            is_archived)
          VALUES ('coffee', 'Coffee', 'coffee', '#123456', 0, 0);
          INSERT INTO expenses (id, budget_id, amount, category_id, note, date,
            time, created_at, updated_at)
          VALUES ('e1', 'b1', 179.5, 'coffee', 'beans', 1789756200,
            1789756200, 1, 1);
          INSERT INTO bills (id, title, amount, currency, category, due_date,
            is_recurring, recurrence_type, created_at, updated_at)
          VALUES ('bill1', 'Rent', 200, 'OMR', 'rent', 1790000000, 1,
            'monthly', 1, 1);
        ''');
      });
    });

    tearDown(() => db.close());

    test('moves the user version to the current schema (9)', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data['user_version'], 9);
      expect(db.schemaVersion, 9);
    });

    test('adds the new columns, all null on existing rows', () async {
      final tables = await schemaOf(db);
      expect(tables['bills'], contains('budget_id'));
      expect(tables['expenses'], contains('bill_id'));
      expect(
        tables['budgets'],
        containsAll(['reserved_amount', 'savings_target']),
      );
      expect(tables['<indexes>'], contains('index_bills_budget'));

      final budget = await db.select(db.budgets).getSingle();
      expect(budget.reservedAmount, isNull);
      expect(budget.savingsTarget, isNull);
      expect((await db.select(db.bills).getSingle()).budgetId, isNull);
      expect((await db.select(db.expenses).getSingle()).billId, isNull);
    });

    test('keeps every existing row exactly as it was', () async {
      final budget = await db.select(db.budgets).getSingle();
      expect(budget.name, 'Home');
      expect(budget.monthlyAmount, 500);
      expect(budget.remainingAmount, 320.5);
      expect(budget.currency, 'OMR');

      final expense = await db.select(db.expenses).getSingle();
      expect(expense.amount, 179.5);
      expect(expense.note, 'beans');
      expect(expense.budgetId, 'b1');

      final bill = await db.select(db.bills).getSingle();
      expect(bill.title, 'Rent');
      expect(bill.amount, 200);
      expect(bill.isRecurring, isTrue);
      expect(bill.recurrenceType, 'monthly');
    });

    test('the new columns accept writes after the upgrade', () async {
      await (db.update(db.budgets)..where((b) => b.id.equals('b1'))).write(
        const BudgetsCompanion(
          reservedAmount: Value(50.25),
          savingsTarget: Value(100),
        ),
      );
      await (db.update(db.bills)..where((b) => b.id.equals('bill1'))).write(
        const BillsCompanion(budgetId: Value('b1')),
      );
      await (db.update(db.expenses)..where((e) => e.id.equals('e1'))).write(
        const ExpensesCompanion(billId: Value('bill1')),
      );

      final budget = await db.select(db.budgets).getSingle();
      expect(budget.reservedAmount, 50.25);
      expect(budget.savingsTarget, 100);
      expect((await db.select(db.bills).getSingle()).budgetId, 'b1');
      expect((await db.select(db.expenses).getSingle()).billId, 'bill1');
    });

    test(
      'bills.budget_id is enforced as a foreign key after upgrade',
      () async {
        expect(
          () => (db.update(db.bills)..where((b) => b.id.equals('bill1'))).write(
            const BillsCompanion(budgetId: Value('missing')),
          ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('the v7 fixture really lacks the new columns', () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v7.sql').readAsStringSync());
      List<Object?> columns(String table) => raw
          .select('PRAGMA table_info($table)')
          .map((r) => r['name'])
          .toList();
      expect(columns('bills'), isNot(contains('budget_id')));
      expect(columns('expenses'), isNot(contains('bill_id')));
      expect(columns('budgets'), isNot(contains('reserved_amount')));
      expect(columns('budgets'), isNot(contains('savings_target')));
      expect(columns('budgets'), contains('currency'));
      raw.dispose();
    });

    test('the v3 fixture really lacks the bills tables', () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v3.sql').readAsStringSync());
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'])
          .toSet();
      expect(tables, isNot(contains('bills')));
      expect(tables, isNot(contains('bill_payments')));
      expect(tables, contains('budgets'));
      raw.dispose();
    });
  });

  group('schema v8 → v9 migration (pay later)', () {
    const payLaterTables = [
      'pay_later_accounts',
      'pay_later_entries',
      'pay_later_payments',
      'pay_later_allocations',
    ];

    Future<List<Map<String, Object?>>> dump(
      AppDatabase db,
      String table,
    ) async {
      final rows = await db
          .customSelect('SELECT * FROM $table ORDER BY 1')
          .get();
      return rows.map((r) => r.data).toList();
    }

    void seedV8(sqlite.Database raw) {
      raw.execute('''
        INSERT INTO budgets (id, name, monthly_amount, remaining_amount,
          currency, start_date, end_date, is_archived, created_at, updated_at)
        VALUES ('b1', 'Home', 500, 320.5, 'OMR', 1789669800, 1792261800, 0,
          1, 1);
        INSERT INTO categories (id, name, icon, color_hex, is_system,
          is_archived)
        VALUES ('coffee', 'Coffee', 'coffee', '#123456', 0, 0);
        INSERT INTO bills (id, title, amount, currency, category, due_date,
          is_recurring, recurrence_type, created_at, updated_at)
        VALUES ('bill1', 'Rent', 200, 'OMR', 'rent', 1790000000, 1,
          'monthly', 1, 1);
        INSERT INTO expenses (id, budget_id, amount, category_id, note, date,
          time, created_at, updated_at, bill_id)
        VALUES ('e1', 'b1', 179.5, 'coffee', 'beans', 1789756200,
          1789756200, 1, 1, NULL),
          ('e2', 'b1', 200, 'coffee', 'rent', 1789756200,
          1789756200, 1, 1, 'bill1');
      ''');
    }

    /// Two tabs-worth of data on a fresh upgraded database: tab `t1` with
    /// purchases `e1`/`e2` and payment `p1` allocated to `e1`.
    Future<AppDatabase> upgradedWithTab() async {
      final db = await openUpgradedFromV8(seedV8);
      addTearDown(db.close);
      await db.customStatement('''
        INSERT INTO pay_later_accounts (id, name, category, currency, rhythm,
          created_at, updated_at)
        VALUES ('t1', 'Cafeteria', 'food_dining', 'OMR', 'on_demand', 1, 1);
        INSERT INTO pay_later_entries (expense_id, account_id, created_at)
        VALUES ('e1', 't1', 1);
        INSERT INTO pay_later_payments (id, account_id, amount, paid_date,
          created_at, updated_at)
        VALUES ('p1', 't1', 50, 1789756200, 1, 1);
        INSERT INTO pay_later_allocations (id, payment_id, expense_id, amount,
          is_manual, created_at)
        VALUES ('a1', 'p1', 'e1', 50, 0, 1);
      ''');
      return db;
    }

    test('keeps every v8 budget, category, expense and bill row unchanged and '
        'adds empty pay later tables', () async {
      final before = await openUpgradedFromV8((_) {});
      // Snapshot reference: same seed, read through a v8-shaped raw DB.
      await before.close();
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v8.sql').readAsStringSync());
      seedV8(raw);
      const keep = ['budgets', 'categories', 'expenses', 'bills'];
      final expected = {
        for (final t in keep)
          t: raw
              .select('SELECT * FROM $t ORDER BY 1')
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
      };
      raw.dispose();

      final db = await openUpgradedFromV8(seedV8);
      addTearDown(db.close);
      for (final t in keep) {
        final actual = await dump(db, t);
        // beforeOpen may seed missing default categories; seeded rows are
        // additions, so compare only the rows that existed before.
        final ids = expected[t]!.map((r) => r.values.first).toSet();
        expect(
          actual.where((r) => ids.contains(r.values.first)).toList(),
          expected[t],
          reason: t,
        );
      }
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data['user_version'], 9);
      for (final t in payLaterTables) {
        final c = await db
            .customSelect('SELECT COUNT(*) AS c FROM $t')
            .getSingle();
        expect(c.data['c'], 0, reason: t);
      }
    });

    test('creates the pay later indexes and unique key', () async {
      final db = await openUpgradedFromV8((_) {});
      addTearDown(db.close);
      final tables = await schemaOf(db);
      expect(
        tables['<indexes>'],
        containsAll([
          'index_pay_later_entries_account',
          'index_pay_later_payments_account_date',
          'index_pay_later_allocations_payment',
          'index_pay_later_allocations_expense',
        ]),
      );
      expect(
        tables['pay_later_accounts'],
        containsAll([
          'rhythm_days',
          'rhythm_day_of_month',
          'rhythm_anchor',
          'next_settle_date',
          'reminder_enabled',
          'reminder_offset_days',
          'default_category_id',
          'is_archived',
        ]),
      );
      expect(
        await foreignKeysOf(db, 'pay_later_entries'),
        containsAll([
          ('expenses', 'expense_id', 'id'),
          ('pay_later_accounts', 'account_id', 'id'),
        ]),
      );
      expect(
        await foreignKeysOf(db, 'pay_later_allocations'),
        containsAll([
          ('pay_later_payments', 'payment_id', 'id'),
          ('pay_later_entries', 'expense_id', 'expense_id'),
        ]),
      );
    });

    test(
      'deleting an expense cascades its link and allocations, keeps the payment',
      () async {
        final db = await upgradedWithTab();
        await db.customStatement("DELETE FROM expenses WHERE id = 'e1'");
        expect(await dump(db, 'pay_later_entries'), isEmpty);
        expect(await dump(db, 'pay_later_allocations'), isEmpty);
        expect(await dump(db, 'pay_later_payments'), hasLength(1));
        expect(await dump(db, 'pay_later_accounts'), hasLength(1));
      },
    );

    test('deleting a payment cascades its allocations only', () async {
      final db = await upgradedWithTab();
      await db.customStatement(
        "DELETE FROM pay_later_payments WHERE id = 'p1'",
      );
      expect(await dump(db, 'pay_later_allocations'), isEmpty);
      expect(await dump(db, 'pay_later_entries'), hasLength(1));
    });

    test(
      'an allocation cannot reference an expense that is not on a tab',
      () async {
        final db = await upgradedWithTab();
        await expectLater(
          db.customStatement('''
            INSERT INTO pay_later_allocations (id, payment_id, expense_id,
              amount, is_manual, created_at)
            VALUES ('a2', 'p1', 'e2', 10, 0, 1)
          '''),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('a payment cannot be allocated twice to the same expense', () async {
      final db = await upgradedWithTab();
      await expectLater(
        db.customStatement('''
          INSERT INTO pay_later_allocations (id, payment_id, expense_id,
            amount, is_manual, created_at)
          VALUES ('a2', 'p1', 'e1', 10, 0, 1)
        '''),
        throwsA(isA<SqliteException>()),
      );
    });

    test('an expense can be on at most one tab', () async {
      final db = await upgradedWithTab();
      await db.customStatement('''
        INSERT INTO pay_later_accounts (id, name, category, currency, rhythm,
          created_at, updated_at)
        VALUES ('t2', 'Other', 'other', 'OMR', 'on_demand', 1, 1)
      ''');
      await expectLater(
        db.customStatement(
          "INSERT INTO pay_later_entries (expense_id, account_id, created_at) "
          "VALUES ('e1', 't2', 1)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('the v8 fixture really lacks the pay later tables', () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute(File('test/fixtures/schema_v8.sql').readAsStringSync());
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'])
          .toSet();
      expect(
        tables.where((t) => (t as String).startsWith('pay_later')),
        isEmpty,
      );
      expect(tables, contains('expenses'));
      raw.dispose();
    });
  });

  group('bills → budgets foreign key', () {
    // schemaOf compares column names only: a raw ALTER TABLE without
    // REFERENCES would pass parity yet let deleteBudget through on upgraded
    // databases while fresh installs block it.
    const budgetLink = ('budgets', 'budget_id', 'id');

    test('is declared on a fresh database', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      expect(await foreignKeysOf(db, 'bills'), contains(budgetLink));
    });

    test('is declared after upgrading from v7', () async {
      final db = await openUpgradedFromV7((_) {});
      addTearDown(db.close);
      expect(await foreignKeysOf(db, 'bills'), contains(budgetLink));
    });

    test('is declared after upgrading from v4', () async {
      final db = await openUpgradedFromV4((_) {});
      addTearDown(db.close);
      expect(await foreignKeysOf(db, 'bills'), contains(budgetLink));
    });

    test('is declared after upgrading from v3', () async {
      final db = await openUpgradedFromV3((_) {});
      addTearDown(db.close);
      expect(await foreignKeysOf(db, 'bills'), contains(budgetLink));
    });

    test('expenses.bill_id has no foreign key', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      final keys = await foreignKeysOf(db, 'expenses');
      expect(keys.map((k) => k.$2), isNot(contains('bill_id')));
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
