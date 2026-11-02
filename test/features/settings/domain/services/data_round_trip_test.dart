import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/domain/services/export_service.dart';
import 'package:monivo/features/settings/domain/services/import_service.dart';

import '../../../../helpers/in_memory_database.dart';
import '../../../../helpers/pay_later_fixtures.dart';

/// Every column of every table the files carry survives the trip: a backup
/// restored, and a data export imported into an empty database. Values are
/// set away from their defaults, so a dropped field shows as a difference.
void main() {
  late AppDatabase source;
  late AppDatabase target;
  late Directory temp;

  setUp(() async {
    source = await createInMemoryDatabase();
    target = await createInMemoryDatabase();
    temp = Directory.systemTemp.createTempSync('monivo_round_trip_');
    await _seedEveryColumn(source);
    await _seedPayLater(source);
  });

  tearDown(() async {
    await source.close();
    await target.close();
    temp.deleteSync(recursive: true);
  });

  Future<String> write(Map<String, Object?> payload) async {
    final file = File('${temp.path}/data.json');
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }

  test('a backup restores every table as it was', () async {
    final path = await write(
      await BackupService(
        database: source,
        reconcileTabs: reconcileTabsOn(source),
      ).buildBackupPayload(),
    );

    await BackupService(
      database: target,
      reconcileTabs: reconcileTabsOn(target),
    ).restore(path);

    expect(
      await _rows(target.budgets, target),
      await _rows(source.budgets, source),
    );
    expect(
      await _rows(target.categories, target),
      await _rows(source.categories, source),
    );
    expect(
      await _rows(target.expenses, target),
      await _rows(source.expenses, source),
    );
    expect(
      await _rows(target.settings, target),
      await _rows(source.settings, source),
    );
    expect(
      await _rows(target.recurringExpenses, target),
      await _rows(source.recurringExpenses, source),
    );
    expect(
      await _rows(target.savingsGoals, target),
      await _rows(source.savingsGoals, source),
    );
    expect(
      await _rows(target.bills, target),
      await _rows(source.bills, source),
    );
    expect(
      await _rows(target.billPayments, target),
      await _rows(source.billPayments, source),
    );
    // Restore reconciles every tab; the seeded allocations are already
    // reconciled, so they come back exactly as they were.
    expect(
      await _rows(target.payLaterAccounts, target),
      await _rows(source.payLaterAccounts, source),
    );
    expect(
      await _rows(target.payLaterEntries, target),
      await _rows(source.payLaterEntries, source),
    );
    expect(
      await _rows(target.payLaterPayments, target),
      await _rows(source.payLaterPayments, source),
    );
    expect(
      await _rows(target.payLaterAllocations, target),
      await _rows(source.payLaterAllocations, source),
    );
    // Not vacuous: every Pay later table had rows to compare.
    expect(await _rows(target.payLaterAccounts, target), hasLength(2));
    expect(await _rows(target.payLaterEntries, target), hasLength(2));
    expect(await _rows(target.payLaterPayments, target), hasLength(2));
    expect(await _rows(target.payLaterAllocations, target), hasLength(2));
  });

  test('a data export imports budgets, categories and expenses as they '
      'were', () async {
    final path = await write(
      await ExportService(database: source).collectJsonData(),
    );

    await ImportService(database: target).importJson(path);

    // Import recalculates what is left of each budget from its expenses.
    List<Object?> withoutRemaining(List<Object?> rows) => [
      for (final row in rows) (row as Budget).copyWith(remainingAmount: 0),
    ];
    expect(
      withoutRemaining(await _rows(target.budgets, target)),
      withoutRemaining(await _rows(source.budgets, source)),
    );
    expect(
      await _rows(target.categories, target),
      await _rows(source.categories, source),
    );
    expect(
      await _rows(target.expenses, target),
      await _rows(source.expenses, source),
    );
  });
}

Future<List<Object?>> _rows<T extends Table, D>(
  TableInfo<T, D> table,
  AppDatabase database,
) async {
  final rows = await database.select(table).get();
  final sorted = rows.map((r) => r as Object?).toList()
    ..sort((a, b) => a.toString().compareTo(b.toString()));
  return sorted;
}

/// One row per table with every column set, none at its default. Times are
/// whole seconds: the database stores seconds.
Future<void> _seedEveryColumn(AppDatabase db) async {
  final created = DateTime(2026, 9, 1, 8, 30, 15);
  final updated = DateTime(2026, 9, 2, 9, 45, 20);
  await db
      .into(db.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: 'budget-1',
          name: 'Household',
          monthlyAmount: 480.250,
          remainingAmount: 470.125,
          currency: 'OMR',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          isArchived: const Value(true),
          color: const Value('#123456'),
          icon: const Value('home'),
          notes: const Value('Rent and food'),
          createdAt: Value(created),
          updatedAt: Value(updated),
          reservedAmount: const Value(40.5),
          savingsTarget: const Value(60.75),
        ),
      );
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: 'pets',
          name: 'Pets',
          icon: 'pets',
          colorHex: '#ABCDEF',
          isSystem: const Value(false),
          isArchived: const Value(true),
        ),
      );
  await db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: 'expense-1',
          budgetId: 'budget-1',
          amount: 10.125,
          categoryId: 'pets',
          note: const Value('Food for Max'),
          date: DateTime(2026, 9, 5),
          time: Value(DateTime(2026, 9, 5, 18, 5, 30)),
          receiptImagePath: const Value('/receipts/1_max.jpg'),
          tags: Value(jsonEncode(['pets', 'monthly'])),
          createdAt: Value(created),
          updatedAt: Value(updated),
          billId: const Value('bill-1'),
        ),
      );
  await db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: 'currencyCode', value: 'OMR'),
      );
  await db
      .into(db.recurringExpenses)
      .insert(
        RecurringExpensesCompanion.insert(
          id: 'recurring-1',
          title: 'Gym',
          amount: 15.5,
          categoryId: 'pets',
          frequency: 'monthly',
          nextDueDate: DateTime(2026, 10, 1),
          isActive: const Value(false),
        ),
      );
  await db
      .into(db.savingsGoals)
      .insert(
        SavingsGoalsCompanion.insert(
          id: 'goal-1',
          title: 'Car',
          targetAmount: 3000,
          currentAmount: const Value(250.5),
          targetDate: DateTime(2027, 6, 1),
        ),
      );
  await db
      .into(db.bills)
      .insert(
        BillsCompanion.insert(
          id: 'bill-1',
          title: 'Internet',
          note: const Value('Fibre'),
          amount: 25.5,
          currency: 'OMR',
          category: 'utilities',
          dueDate: DateTime(2026, 9, 20),
          dueTime: Value(DateTime(2026, 9, 20, 10, 15, 5)),
          isRecurring: const Value(true),
          recurrenceType: const Value('weekly'),
          recurrenceInterval: const Value(2),
          reminderEnabled: const Value(true),
          reminderOffsetDays: const Value(3),
          isPaid: const Value(true),
          paidDate: Value(DateTime(2026, 9, 19, 11, 0, 7)),
          createdAt: Value(created),
          updatedAt: Value(updated),
          budgetId: const Value('budget-1'),
        ),
      );
  await db
      .into(db.billPayments)
      .insert(
        BillPaymentsCompanion.insert(
          id: 'payment-1',
          billId: 'bill-1',
          amount: 25.5,
          currency: 'OMR',
          paidDate: DateTime(2026, 9, 19),
          createdAt: Value(created),
        ),
      );
}

/// Pay later rows with every column set away from its default, and every
/// nullable column both set (`tab-full`, `tab-payment-1`) and null
/// (`tab-bare`, `tab-payment-2`). Rhythm columns are stored raw, so all of
/// them are set on one row even though a rhythm reads only some.
///
/// The allocations are what reconcile would leave (each payment fully
/// applied, no purchase over-paid), so a restore that reconciles keeps them.
Future<void> _seedPayLater(AppDatabase db) async {
  final created = DateTime(2026, 9, 3, 7, 10, 11);
  final updated = DateTime(2026, 9, 4, 6, 20, 22);
  for (final (id, amount) in [
    ('tab-purchase-1', 10.125),
    ('tab-purchase-2', 3.5),
  ]) {
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: id,
            budgetId: 'budget-1',
            amount: amount,
            categoryId: 'pets',
            date: DateTime(2026, 9, 6),
            time: Value(DateTime(2026, 9, 6, 13, 14, 15)),
            createdAt: Value(created),
            updatedAt: Value(updated),
          ),
        );
  }
  await db
      .into(db.payLaterAccounts)
      .insert(
        PayLaterAccountsCompanion.insert(
          id: 'tab-full',
          name: 'Corner shop',
          category: 'groceries',
          currency: 'OMR',
          note: const Value('Pay on Fridays'),
          contact: const Value('+968 9000 0000'),
          defaultCategoryId: const Value('pets'),
          rhythm: 'every_days',
          rhythmDays: const Value(14),
          rhythmDayOfMonth: const Value(31),
          rhythmAnchor: Value(DateTime(2026, 9, 1, 0, 0, 1)),
          nextSettleDate: Value(DateTime(2026, 9, 15, 0, 0, 2)),
          reminderEnabled: const Value(true),
          reminderOffsetDays: const Value(2),
          isArchived: const Value(true),
          createdAt: Value(created),
          updatedAt: Value(updated),
        ),
      );
  await db
      .into(db.payLaterAccounts)
      .insert(
        PayLaterAccountsCompanion.insert(
          id: 'tab-bare',
          name: 'Cafeteria',
          category: 'food_dining',
          currency: 'USD',
          rhythm: 'on_demand',
          createdAt: Value(created),
          updatedAt: Value(updated),
        ),
      );
  await db
      .into(db.payLaterEntries)
      .insert(
        PayLaterEntriesCompanion.insert(
          expenseId: 'tab-purchase-1',
          accountId: 'tab-full',
          createdAt: Value(created),
        ),
      );
  await db
      .into(db.payLaterEntries)
      .insert(
        PayLaterEntriesCompanion.insert(
          expenseId: 'tab-purchase-2',
          accountId: 'tab-full',
          createdAt: Value(updated),
        ),
      );
  await db
      .into(db.payLaterPayments)
      .insert(
        PayLaterPaymentsCompanion.insert(
          id: 'tab-payment-1',
          accountId: 'tab-full',
          amount: 3.5,
          paidDate: DateTime(2026, 9, 10, 17, 30, 45),
          note: const Value('Cash'),
          createdAt: Value(created),
          updatedAt: Value(updated),
        ),
      );
  await db
      .into(db.payLaterPayments)
      .insert(
        PayLaterPaymentsCompanion.insert(
          id: 'tab-payment-2',
          accountId: 'tab-full',
          amount: 2.25,
          paidDate: DateTime(2026, 9, 11, 8, 0, 3),
          createdAt: Value(created),
          updatedAt: Value(updated),
        ),
      );
  await db
      .into(db.payLaterAllocations)
      .insert(
        PayLaterAllocationsCompanion.insert(
          id: 'allocation-1',
          paymentId: 'tab-payment-1',
          expenseId: 'tab-purchase-2',
          amount: 3.5,
          isManual: true,
          createdAt: Value(created),
        ),
      );
  await db
      .into(db.payLaterAllocations)
      .insert(
        PayLaterAllocationsCompanion.insert(
          id: 'allocation-2',
          paymentId: 'tab-payment-2',
          expenseId: 'tab-purchase-1',
          amount: 2.25,
          isManual: false,
          createdAt: Value(updated),
        ),
      );
}
