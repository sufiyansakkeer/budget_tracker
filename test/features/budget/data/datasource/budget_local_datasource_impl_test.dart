import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

/// Schema v8 behaviour of the budget data source on a real in-memory
/// database: the reserve/savings columns round-trip (including clearing), a
/// deleted budget unlinks its bills, and a duplicate copies the plan but not
/// the bills.
void main() {
  late AppDatabase database;
  late BudgetLocalDataSourceImpl dataSource;

  final created = DateTime(2026, 8, 1, 9);

  BudgetEntity budget(String id, {double? reserved, double? savings}) {
    return BudgetEntity(
      id: id,
      name: 'Budget $id',
      monthlyAmount: 500,
      remainingAmount: 500,
      currency: 'OMR',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      createdAt: created,
      updatedAt: created,
      reservedAmount: reserved,
      savingsTarget: savings,
    );
  }

  Future<void> insertBill(String id, {String? budgetId}) async {
    await database
        .into(database.bills)
        .insert(
          BillsCompanion.insert(
            id: id,
            title: 'Bill $id',
            amount: 50,
            currency: 'OMR',
            category: 'utilities',
            dueDate: DateTime(2026, 8, 20),
            budgetId: Value(budgetId),
          ),
        );
  }

  Future<Map<String, String?>> billLinks() async => {
    for (final b in await database.select(database.bills).get())
      b.id: b.budgetId,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = await createInMemoryDatabase();
    dataSource = BudgetLocalDataSourceImpl(
      database: database,
      sharedPreferences: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() => database.close());

  group('BudgetEntity set-aside fields', () {
    test('default to not set and take part in equality', () {
      final plain = budget('b1');
      expect(plain.reservedAmount, isNull);
      expect(plain.savingsTarget, isNull);
      expect(plain.copyWith(reservedAmount: 0), isNot(plain));
      expect(plain.copyWith(savingsTarget: 10), isNot(plain));
    });

    test('copyWith keeps values unless told to clear them', () {
      final planned = budget('b1', reserved: 40, savings: 60);
      final renamed = planned.copyWith(name: 'Renamed');
      expect(renamed.reservedAmount, 40);
      expect(renamed.savingsTarget, 60);

      final cleared = planned.copyWith(
        clearReservedAmount: true,
        clearSavingsTarget: true,
      );
      expect(cleared.reservedAmount, isNull);
      expect(cleared.savingsTarget, isNull);
    });
  });

  group('BudgetModel mapping', () {
    test('create, read and update round-trip the set-aside fields', () async {
      await dataSource.createBudget(budget('b1', reserved: 12.345, savings: 0));
      var stored = await dataSource.getBudgetById('b1');
      expect(stored!.reservedAmount, 12.345);
      // Zero is a value, distinct from "not set".
      expect(stored.savingsTarget, 0);

      await dataSource.updateBudget(
        stored.copyWith(clearReservedAmount: true, savingsTarget: 25),
      );
      stored = await dataSource.getBudgetById('b1');
      expect(stored!.reservedAmount, isNull);
      expect(stored.savingsTarget, 25);
    });

    test('archiving leaves the set-aside fields alone', () async {
      await dataSource.createBudget(budget('b1', reserved: 40, savings: 60));
      final archived = await dataSource.setBudgetArchived('b1', archived: true);
      expect(archived.reservedAmount, 40);
      expect(archived.savingsTarget, 60);
    });
  });

  group('deleteBudget', () {
    test('unlinks the budget\'s bills and keeps them', () async {
      await dataSource.createBudget(budget('b1'));
      await dataSource.createBudget(budget('b2'));
      await insertBill('linked', budgetId: 'b1');
      await insertBill('other', budgetId: 'b2');
      await insertBill('free');

      await dataSource.deleteBudget('b1');

      expect(await dataSource.getBudgetById('b1'), isNull);
      expect(await billLinks(), {'linked': null, 'other': 'b2', 'free': null});
    });
  });

  group('duplicateBudget', () {
    test('copies the reserve and savings goal but not the bills', () async {
      await dataSource.createBudget(budget('b1', reserved: 40, savings: 60));
      await insertBill('linked', budgetId: 'b1');

      final copy = await dataSource.duplicateBudget('b1', newName: 'Copy');

      expect(copy.reservedAmount, 40);
      expect(copy.savingsTarget, 60);
      final stored = await dataSource.getBudgetById(copy.id);
      expect(stored!.reservedAmount, 40);
      expect(stored.savingsTarget, 60);
      expect(await billLinks(), {'linked': 'b1'});
    });

    test('an unset plan stays unset on the copy', () async {
      await dataSource.createBudget(budget('b1'));
      final copy = await dataSource.duplicateBudget('b1', newName: 'Copy');
      expect(copy.reservedAmount, isNull);
      expect(copy.savingsTarget, isNull);
    });
  });
}
