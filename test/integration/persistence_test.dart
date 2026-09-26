import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/preference_keys.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/data/datasource/bill_local_datasource_impl.dart';
import 'package:monivo/features/bills/data/repository/bill_repository_impl.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/settings/data/datasource/settings_local_datasource_impl.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// One "run" of the app against a database *file*: the real datasources and
/// repositories over a Drift connection that is closed at the end, so the
/// next [Session] on the same file starts exactly like the app after being
/// killed and relaunched. Preferences are the mocked SharedPreferences,
/// which survive across sessions in-process the way the platform store does.
class Session {
  final AppDatabase database;
  final SharedPreferences prefs;
  final BudgetRepositoryImpl budgets;
  final ExpenseRepositoryImpl expenses;
  final BillRepositoryImpl bills;
  final SettingsLocalDataSourceImpl settings;

  Session._(
    this.database,
    this.prefs,
    this.budgets,
    this.expenses,
    this.bills,
    this.settings,
  );

  static Future<Session> open(File file) async {
    final database = AppDatabase(executor: NativeDatabase(file));
    final prefs = await SharedPreferences.getInstance();
    final budgets = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: database,
        sharedPreferences: prefs,
      ),
      calculationService: BudgetCalculationService(),
    );
    final expenses = ExpenseRepositoryImpl(
      localDataSource: ExpenseLocalDataSourceImpl(database: database),
      budgetRepository: budgets,
    );
    final bills = BillRepositoryImpl(
      localDataSource: BillLocalDataSourceImpl(database: database),
    );
    final settings = SettingsLocalDataSourceImpl(
      database: database,
      sharedPreferences: prefs,
    );
    return Session._(database, prefs, budgets, expenses, bills, settings);
  }

  Future<void> close() => database.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File dbFile;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('monivo_persistence_');
    dbFile = File(p.join(dir.path, 'smart_monivo_db.sqlite'));
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => dir.delete(recursive: true));

  /// Runs [body] in a fresh session and closes it afterwards, even on failure.
  Future<T> run<T>(Future<T> Function(Session app) body) async {
    final app = await Session.open(dbFile);
    try {
      return await body(app);
    } finally {
      await app.close();
    }
  }

  final createdAt = DateTime(2026, 9, 18, 14, 35, 12);

  BudgetEntity budget(
    String id, {
    String name = 'Personal',
    double amount = 3700,
    String currency = 'INR',
    DateTime? start,
    DateTime? end,
    String? color,
    String? notes,
  }) {
    final s = start ?? DateTime(2026, 9, 18);
    return BudgetEntity(
      id: id,
      name: name,
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: currency,
      startDate: s,
      endDate: end ?? s.add(const Duration(days: 30)),
      color: color,
      notes: notes,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  ExpenseEntity expense(
    String id, {
    required String budgetId,
    double amount = 349,
    String categoryId = 'grocery',
    String? note,
    DateTime? date,
    DateTime? time,
    List<String> tags = const [],
  }) {
    return ExpenseEntity(
      id: id,
      budgetId: budgetId,
      amount: amount,
      categoryId: categoryId,
      note: note,
      date: date ?? DateTime(2026, 9, 19),
      time: time ?? DateTime(2026, 9, 19, 14, 8),
      tags: tags,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('a budget comes back exactly as stored after a restart', () async {
    final stored = budget(
      'b1',
      name: 'new ly',
      amount: 3700.5,
      currency: 'OMR',
      start: DateTime(2026, 9, 18),
      end: DateTime(2026, 10, 18),
      color: '#4ECDC4',
      notes: 'rent + food',
    );
    await run((app) async {
      await app.budgets.createBudget(stored);
      await app.budgets.setActiveBudgetId('b1');
    });

    await run((app) async {
      final loaded = await app.budgets.getBudgetById('b1');
      expect(loaded, stored);
      expect(loaded!.startDate, DateTime(2026, 9, 18));
      expect(loaded.endDate, DateTime(2026, 10, 18));
      expect(loaded.currency, 'OMR');
      expect(await app.budgets.getActiveBudgetId(), 'b1');
      expect((await app.budgets.getActiveBudget())?.name, 'new ly');
    });
  });

  test('an expense keeps every field and its budget after a restart', () async {
    final stored = expense(
      'e1',
      budgetId: 'b1',
      amount: 123.45,
      categoryId: 'food',
      note: 'lunch',
      date: DateTime(2026, 9, 19),
      time: DateTime(2026, 9, 19, 13, 16),
      tags: ['work', 'client'],
    );
    await run((app) async {
      await app.budgets.createBudget(budget('b1', amount: 1000));
      await app.expenses.createExpense(stored);
    });

    await run((app) async {
      final loaded = await app.expenses.getExpenseById('e1');
      expect(loaded, stored);
      expect(loaded!.date, DateTime(2026, 9, 19));
      expect(loaded.time, DateTime(2026, 9, 19, 13, 16));
      expect(loaded.tags, ['work', 'client']);
      // The derived remaining amount was persisted with the expense.
      expect((await app.budgets.getBudgetById('b1'))?.remainingAmount, 876.55);
      final listed = await app.expenses.getExpenses(budgetId: 'b1');
      expect(listed.map((e) => e.id), ['e1']);
    });
  });

  test('expenses stay attached to their own budget across restarts', () async {
    await run((app) async {
      await app.budgets.createBudget(budget('daily', amount: 2100));
      await app.budgets.createBudget(
        budget('monthly', amount: 3700, start: DateTime(2026, 9, 1)),
      );
      await app.expenses.createExpense(
        expense('d1', budgetId: 'daily', amount: 300, categoryId: 'food'),
      );
      await app.expenses.createExpense(
        expense('m1', budgetId: 'monthly', amount: 349),
      );
      await app.expenses.createExpense(
        expense('m2', budgetId: 'monthly', amount: 45, categoryId: 'rent'),
      );
    });

    await run((app) async {
      final daily = await app.expenses.getExpenses(budgetId: 'daily');
      final monthly = await app.expenses.getExpenses(budgetId: 'monthly');
      expect(daily.map((e) => e.id), ['d1']);
      expect(monthly.map((e) => e.id).toSet(), {'m1', 'm2'});
      expect((await app.budgets.getBudgetById('daily'))?.remainingAmount, 1800);
      expect(
        (await app.budgets.getBudgetById('monthly'))?.remainingAmount,
        3306,
      );

      // Combined view reads both, unfiltered by the active budget.
      final combined = await app.expenses.getExpensesForBudgets(
        budgetIds: ['daily', 'monthly'],
      );
      expect(combined.length, 3);
      expect(
        {for (final e in combined) e.id: e.budgetId},
        {'d1': 'daily', 'm1': 'monthly', 'm2': 'monthly'},
      );
    });
  });

  test('edits and deletes are what the next run sees', () async {
    await run((app) async {
      await app.budgets.createBudget(budget('b1', amount: 1000));
      await app.expenses.createExpense(
        expense('e1', budgetId: 'b1', amount: 100),
      );
      await app.expenses.createExpense(
        expense('e2', budgetId: 'b1', amount: 50),
      );
    });

    await run((app) async {
      final e1 = (await app.expenses.getExpenseById('e1'))!;
      await app.expenses.updateExpense(
        e1.copyWith(amount: 250, note: 'corrected', categoryId: 'rent'),
      );
      await app.expenses.deleteExpense('e2');
      final b1 = (await app.budgets.getBudgetById('b1'))!;
      await app.budgets.updateBudget(b1.copyWith(monthlyAmount: 2000));
    });

    await run((app) async {
      final e1 = (await app.expenses.getExpenseById('e1'))!;
      expect(e1.amount, 250);
      expect(e1.note, 'corrected');
      expect(e1.categoryId, 'rent');
      expect(await app.expenses.getExpenseById('e2'), isNull);
      final b1 = (await app.budgets.getBudgetById('b1'))!;
      expect(b1.monthlyAmount, 2000);
      expect(b1.remainingAmount, 1750);
    });
  });

  test(
    'deleting the active budget does not leave the app with no budget',
    () async {
      await run((app) async {
        await app.budgets.createBudget(budget('keep'));
        await app.budgets.createBudget(
          budget('drop', start: DateTime(2026, 9, 20)),
        );
        await app.budgets.setActiveBudgetId('drop');
        await app.budgets.deleteBudget('drop');
      });

      await run((app) async {
        expect(await app.budgets.getActiveBudgetId(), 'keep');
        expect(app.prefs.getString(PreferenceKeys.activeBudgetId), 'keep');
      });
    },
  );

  test(
    'restoring a backup with different ids keeps an active budget',
    () async {
      // Build a backup from one database, restore it into another whose
      // preferences still point at a budget that no longer exists.
      late Map<String, Object?> payload;
      await run((app) async {
        await app.budgets.createBudget(budget('from-backup', amount: 5000));
        await app.expenses.createExpense(
          expense('e1', budgetId: 'from-backup', amount: 20),
        );
        payload = await BackupService(
          database: app.database,
          appVersionResolver: () async => 'test',
        ).buildBackupPayload();
      });
      final backupFile = File(p.join(dir.path, 'backup.json'))
        ..writeAsStringSync(jsonEncode(payload));

      await run((app) async {
        await app.budgets.createBudget(budget('current'));
        await app.budgets.setActiveBudgetId('current');
        await BackupService(
          database: app.database,
          appVersionResolver: () async => 'test',
        ).restore(backupFile.path);
      });

      await run((app) async {
        expect(await app.budgets.getBudgetById('current'), isNull);
        expect(await app.budgets.getActiveBudgetId(), 'from-backup');
        final restored = (await app.budgets.getBudgetById('from-backup'))!;
        expect(restored.monthlyAmount, 5000);
        expect(restored.remainingAmount, 4980);
        expect(
          (await app.expenses.getExpenses(
            budgetId: 'from-backup',
          )).single.amount,
          20,
        );
      });
    },
  );

  test('settings survive a restart', () async {
    await run((app) async {
      await app.settings.setThemeMode(AppThemeMode.dark);
      await app.settings.setPalette(ColorPalette.values.last);
      await app.settings.setCurrency('OMR', 'ر.ع.');
      await app.settings.setBiometricEnabled(true);
      await app.settings.setFirstLaunchCompleted();
    });

    await run((app) async {
      final loaded = await app.settings.loadSettings();
      expect(loaded.themeMode, AppThemeMode.dark);
      expect(loaded.colorPalette, ColorPalette.values.last);
      expect(loaded.currencyCode, 'OMR');
      expect(loaded.biometricEnabled, isTrue);
      expect(loaded.firstLaunchCompleted, isTrue);
    });
  });

  test(
    'bills survive a restart with their status derived from the due date',
    () async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      BillEntity bill(String id, DateTime due, {bool paid = false}) =>
          BillEntity(
            id: id,
            title: id,
            amount: 99.5,
            currency: 'INR',
            category: BillCategory.utilities,
            dueDate: due,
            dueTime: DateTime(due.year, due.month, due.day, 9, 30),
            isRecurring: true,
            recurrenceType: RecurrenceType.monthly,
            reminderEnabled: true,
            reminderOffsetDays: 2,
            isPaid: paid,
            paidDate: paid ? todayDate : null,
            createdAt: createdAt,
            updatedAt: createdAt,
          );
      await run((app) async {
        await app.bills.createBill(
          bill('overdue', todayDate.subtract(const Duration(days: 3))),
        );
        await app.bills.createBill(bill('today', todayDate));
        await app.bills.createBill(
          bill('soon', todayDate.add(const Duration(days: 5))),
        );
        await app.bills.createBill(bill('done', todayDate, paid: true));
      });

      await run((app) async {
        final byId = {for (final b in await app.bills.getBills()) b.id: b};
        expect(byId['overdue']?.status, BillStatus.overdue);
        expect(byId['today']?.status, BillStatus.dueToday);
        expect(byId['soon']?.status, BillStatus.upcoming);
        expect(byId['done']?.status, BillStatus.paid);
        expect(
          byId['soon']?.dueTime,
          DateTime(
            byId['soon']!.dueDate.year,
            byId['soon']!.dueDate.month,
            byId['soon']!.dueDate.day,
            9,
            30,
          ),
        );
        expect(byId['soon']?.recurrenceType, RecurrenceType.monthly);
        expect(byId['soon']?.amount, 99.5);
        final upcoming = await app.bills.getUpcomingBills(limit: 5);
        expect(upcoming.map((b) => b.id), ['today', 'soon']);
      });
    },
  );
}
