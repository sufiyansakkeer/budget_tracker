import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Expenses Table
@TableIndex(name: 'index_expenses_date', columns: {#date})
@TableIndex(name: 'index_expenses_category', columns: {#categoryId})
@TableIndex(name: 'index_expenses_budget', columns: {#budgetId})
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

@DriftDatabase(
  tables: [
    Budgets,
    Categories,
    Expenses,
    Settings,
    RecurringExpenses,
    SavingsGoals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(expenses, expenses.time);
        }
        if (from < 3) {
          // Migrate from single-budget (month/year) to multi-budget (date range)
          // Use raw SQL because generated column types are not yet available
          await customStatement(
            "ALTER TABLE budgets ADD COLUMN name TEXT NOT NULL DEFAULT 'Personal Budget'",
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN startDate INTEGER',
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN endDate INTEGER',
          );
          await customStatement(
            'ALTER TABLE budgets ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement('ALTER TABLE budgets ADD COLUMN color TEXT');
          await customStatement('ALTER TABLE budgets ADD COLUMN icon TEXT');
          await customStatement('ALTER TABLE budgets ADD COLUMN notes TEXT');
          await customStatement(
            'ALTER TABLE expenses ADD COLUMN budgetId TEXT',
          );

          // Backfill: Set startDate = 1st of month, endDate = last day of month
          await customStatement('''
            UPDATE budgets
            SET startDate = strftime('%s', year || '-' || printf('%02d', month) || '-01') * 1000,
                endDate = strftime('%s', year || '-' || printf('%02d', month) || '-01', '+1 month', '-1 day') * 1000
            WHERE startDate IS NULL;
          ''');

          // Backfill: Assign all existing expenses to the first budget
          await customStatement('''
            UPDATE expenses
            SET budgetId = (SELECT id FROM budgets LIMIT 1)
            WHERE budgetId IS NULL;
          ''');
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'smart_monivo_db');
  }
}
