import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'default_categories.dart';

part 'app_database.g.dart';

// 1. Budgets Table
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get monthlyAmount => real()();
  RealColumn get remainingAmount => real()();
  TextColumn get currency => text().withLength(min: 1, max: 10)();
  IntColumn get month => integer().nullable()();
  IntColumn get year => integer().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [];
}

// 2. Categories Table
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get colorHex => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(true))();

  /// Archived categories are hidden from pickers but keep their expenses.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Expenses Table
@TableIndex(name: 'index_expenses_date', columns: {#date})
@TableIndex(name: 'index_expenses_category', columns: {#categoryId})
@TableIndex(name: 'index_expenses_budget', columns: {#budgetId})
@TableIndex(name: 'index_expenses_budget_date', columns: {#budgetId, #date})
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId => text().references(Budgets, #id)();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get time => dateTime().withDefault(currentDateAndTime)();
  TextColumn get receiptImagePath => text().nullable()();
  TextColumn get tags => text().nullable()(); // JSON string or comma-separated
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Settings Table
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// 5. Recurring Expenses Table
class RecurringExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get frequency => text()(); // daily, weekly, monthly, yearly
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// 6. Savings Goals Table
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// 7. Bills Table
@TableIndex(name: 'index_bills_due_date', columns: {#dueDate})
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get category => text()();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get dueTime => dateTime().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceType => text().withDefault(const Constant('none'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get reminderOffsetDays =>
      integer().withDefault(const Constant(1))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 8. Bill Payments Table (payment history for recurring bills)
class BillPayments extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text().references(Bills, #id)();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  DateTimeColumn get paidDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 9. Exchange Rates Table (currency converter cache)
//
// One row per provider rate, keyed `BASE_QUOTE` (e.g. `OMR_INR`). The rate
// itself is stored, never a converted amount, so any later amount converts
// locally. `rate` is exact decimal text as the provider returned it (a REAL
// column would be fine for 249.33 but not for arithmetic done on it), and
// `rate_date` is the provider's reference day as `yyyy-MM-dd`, which stays
// timezone-proof unlike a DateTime column.
@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();
  TextColumn get rate => text()();
  TextColumn get rateDate => text()();
  DateTimeColumn get fetchedAt => dateTime()();
  TextColumn get provider => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// 10. Converter Currencies Table (supported-currency list cache)
@DataClassName('ConverterCurrencyRow')
class ConverterCurrencies extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get symbol => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

@DriftDatabase(
  tables: [
    Budgets,
    Categories,
    Expenses,
    Settings,
    RecurringExpenses,
    SavingsGoals,
    Bills,
    BillPayments,
    ExchangeRates,
    ConverterCurrencies,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        developer.log(
          '[Database] Creating schema v$schemaVersion',
          name: 'Database',
        );
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        developer.log('[Database] Migrating v$from → v$to', name: 'Database');
        if (from < 2) {
          await m.addColumn(expenses, expenses.time);
        }
        if (from < 3) {
          // Single-budget (month/year) → multi-budget (date range). Drift maps
          // Dart getters to snake_case SQL columns, so raw SQL must use the
          // snake_case names.
          await customStatement(
            "ALTER TABLE budgets ADD COLUMN name TEXT NOT NULL DEFAULT 'Personal Budget'",
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN start_date INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN end_date INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement('ALTER TABLE budgets ADD COLUMN color TEXT');
          await customStatement('ALTER TABLE budgets ADD COLUMN icon TEXT');
          await customStatement('ALTER TABLE budgets ADD COLUMN notes TEXT');
          await customStatement(
            "ALTER TABLE expenses ADD COLUMN budget_id TEXT NOT NULL DEFAULT ''",
          );
          await _backfillLegacyBudgetDates();
          await _repairOrphanExpenses();
        }
        if (from < 4) {
          await m.createTable(bills);
          await m.createTable(billPayments);
        }
        if (from < 5) {
          // v5 hardens the schema:
          // 1. self-heal databases whose v3 migration wrote camelCase columns,
          // 2. make sure every index exists (older upgraders missed some),
          // 3. add the composite (budget_id, date) index used by every budget
          //    statistic query,
          // 4. seed categories and repair dangling references so foreign-key
          //    enforcement (enabled in beforeOpen) can never fail a write.
          await _healLegacyColumns();
          await _ensureCategoryArchiveColumn(m);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS index_expenses_date ON expenses (date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS index_expenses_category '
            'ON expenses (category_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS index_expenses_budget '
            'ON expenses (budget_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS index_expenses_budget_date '
            'ON expenses (budget_id, date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS index_bills_due_date ON bills (due_date)',
          );
          await seedDefaultCategories();
          await _repairOrphanExpenses();
        }
        if (from < 6) {
          // `categories.is_archived` was added to the table definition after
          // v5 had already shipped to test devices, inside the `from < 5`
          // block above — so a database that was upgraded (or created) by
          // that first v5 build sat at version 5 without the column and
          // every category read failed with a null-check error. v6 exists
          // only to run the same idempotent step for those databases.
          await _ensureCategoryArchiveColumn(m);
          // Same class of repair: budgets healed from the camelCase columns
          // by an earlier v5 build kept their millisecond timestamps.
          await _normaliseBudgetDateUnits();
        }
        if (from < 7) {
          // Currency converter caches. New tables only: no existing row is
          // read, changed or removed.
          await m.createTable(exchangeRates);
          await m.createTable(converterCurrencies);
        }
      },
      beforeOpen: (details) async {
        developer.log(
          '[Database] beforeOpen: version=${details.versionNow}, '
          'type=${details.wasCreated ? "created" : "opened"}',
          name: 'Database',
        );

        // SQLite does not enforce REFERENCES clauses unless this pragma is on
        // for the connection. Migrations above run before it, so legacy data
        // is repaired first and every later write is checked.
        await customStatement('PRAGMA foreign_keys = ON');

        // Categories must exist before the first expense can be written.
        await seedDefaultCategories();

        // Run integrity check on existing databases (not fresh ones).
        if (!details.wasCreated) {
          try {
            final result = await customSelect(
              'PRAGMA integrity_check',
            ).getSingleOrNull();
            final status = result?.data['integrity_check'] ?? 'unknown';
            if (status != 'ok') {
              developer.log(
                '[Database] ⚠️ Integrity check failed: $status',
                name: 'Database',
              );
            } else {
              developer.log('[Database] Integrity check: OK', name: 'Database');
            }
          } catch (e) {
            developer.log(
              '[Database] ⚠️ Could not run integrity check: $e',
              name: 'Database',
            );
          }
        }
      },
    );
  }

  /// Inserts the default categories that are missing. Idempotent and cheap:
  /// a single count query when everything is already present.
  Future<void> seedDefaultCategories() async {
    final countExp = categories.id.count();
    final row = await (selectOnly(
      categories,
    )..addColumns([countExp])).getSingle();
    if ((row.read(countExp) ?? 0) >= defaultCategoryRows.length) return;

    await batch((b) {
      b.insertAll(categories, [
        for (final c in defaultCategoryRows)
          CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            icon: c.icon,
            colorHex: c.colorHex,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  /// Points expenses at a real budget/category when their reference is
  /// dangling (pre-v5 backfills could assign an arbitrary or missing budget).
  Future<void> _repairOrphanExpenses() async {
    await customStatement(
      'UPDATE expenses '
      'SET budget_id = (SELECT id FROM budgets WHERE is_archived = 0 '
      'ORDER BY start_date DESC LIMIT 1) '
      'WHERE budget_id NOT IN (SELECT id FROM budgets) '
      'AND EXISTS (SELECT 1 FROM budgets WHERE is_archived = 0)',
    );
    await customStatement(
      'UPDATE expenses '
      'SET budget_id = (SELECT id FROM budgets ORDER BY start_date DESC LIMIT 1) '
      'WHERE budget_id NOT IN (SELECT id FROM budgets) '
      'AND EXISTS (SELECT 1 FROM budgets)',
    );
    await customStatement(
      "UPDATE expenses SET category_id = '$fallbackCategoryId' "
      'WHERE category_id NOT IN (SELECT id FROM categories) '
      "AND EXISTS (SELECT 1 FROM categories WHERE id = '$fallbackCategoryId')",
    );
  }

  /// Adds `categories.is_archived` when it is missing. Idempotent, so every
  /// migration step that may run against a database without it can call it.
  Future<void> _ensureCategoryArchiveColumn(Migrator m) async {
    if (!(await _columnNames('categories')).contains('is_archived')) {
      await m.addColumn(categories, categories.isArchived);
    }
  }

  /// Budgets created before v3 only had month/year: derive the date range.
  /// Drift stores DateTime columns as unix *seconds* and reads them back in
  /// local time, so the boundaries are local midnight (the `'utc'` modifier
  /// tells SQLite the literal date is local and converts it to UTC), never
  /// UTC midnight, which would land on the previous day west of Greenwich.
  Future<void> _backfillLegacyBudgetDates() async {
    await customStatement(
      'UPDATE budgets SET '
      "start_date = strftime('%s', year || '-' || printf('%02d', month) || '-01', 'utc'), "
      "end_date = strftime('%s', year || '-' || printf('%02d', month) || '-01', '+1 month', '-1 day', 'utc') "
      'WHERE (start_date IS NULL OR start_date = 0) '
      'AND year IS NOT NULL AND month IS NOT NULL',
    );
  }

  /// The migration shipped in every 1.x release wrote the legacy camelCase
  /// `startDate`/`endDate` in unix *milliseconds*. Drift reads seconds, so a
  /// value copied verbatim lands in the year 57,000 and the budget never
  /// contains today. Anything above 10^11 (the year 5138 in seconds) can only
  /// be milliseconds.
  Future<void> _normaliseBudgetDateUnits() async {
    const threshold = 100000000000;
    for (final column in ['start_date', 'end_date']) {
      await customStatement(
        'UPDATE budgets SET $column = $column / 1000 WHERE $column > $threshold',
      );
    }
  }

  /// Adds any snake_case column a broken earlier migration left out and
  /// copies data from the camelCase twin when one exists.
  Future<void> _healLegacyColumns() async {
    final budgetColumns = await _columnNames('budgets');
    const budgetSpecs = <String, String>{
      'name': "TEXT NOT NULL DEFAULT 'Personal Budget'",
      'start_date': 'INTEGER NOT NULL DEFAULT 0',
      'end_date': 'INTEGER NOT NULL DEFAULT 0',
      'is_archived': 'INTEGER NOT NULL DEFAULT 0',
      'color': 'TEXT',
      'icon': 'TEXT',
      'notes': 'TEXT',
    };
    for (final entry in budgetSpecs.entries) {
      if (budgetColumns.contains(entry.key)) continue;
      await customStatement(
        'ALTER TABLE budgets ADD COLUMN ${entry.key} ${entry.value}',
      );
      final camel = _camel(entry.key);
      if (camel != entry.key && budgetColumns.contains(camel)) {
        await customStatement(
          'UPDATE budgets SET ${entry.key} = $camel WHERE $camel IS NOT NULL',
        );
      }
    }
    await _normaliseBudgetDateUnits();
    await _backfillLegacyBudgetDates();

    final expenseColumns = await _columnNames('expenses');
    if (!expenseColumns.contains('budget_id')) {
      await customStatement(
        "ALTER TABLE expenses ADD COLUMN budget_id TEXT NOT NULL DEFAULT ''",
      );
      if (expenseColumns.contains('budgetId')) {
        await customStatement(
          "UPDATE expenses SET budget_id = COALESCE(budgetId, '')",
        );
      }
    }
  }

  Future<Set<String>> _columnNames(String table) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  static String _camel(String snake) {
    final parts = snake.split('_');
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'smart_monivo_db');
  }
}
