import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/data/repository/expense_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

/// `expenses.bill_id` marks committed spending. It is written only when the
/// expense is created by paying a bill, never by an edit (edit forms build a
/// fresh entity without it), and cleared when the expense moves to another
/// budget, where it is plain spending.
void main() {
  late AppDatabase database;
  late ExpenseRepositoryImpl repository;

  final day = DateTime(2026, 8, 20, 9, 30);

  ExpenseEntity expense({
    String budgetId = 'b1',
    double amount = 200,
    String? billId,
    String? note,
  }) {
    return ExpenseEntity(
      id: 'e1',
      budgetId: budgetId,
      amount: amount,
      categoryId: 'bills',
      note: note,
      date: day,
      time: day,
      createdAt: day,
      updatedAt: day,
      billId: billId,
    );
  }

  Future<String?> storedBillId() async =>
      (await database.select(database.expenses).getSingle()).billId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = await createInMemoryDatabase();
    for (final id in ['b1', 'b2']) {
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: id,
              name: 'Budget $id',
              monthlyAmount: 500,
              remainingAmount: 500,
              currency: 'OMR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
            ),
          );
    }
    repository = ExpenseRepositoryImpl(
      localDataSource: ExpenseLocalDataSourceImpl(database: database),
      budgetRepository: BudgetRepositoryImpl(
        localDataSource: BudgetLocalDataSourceImpl(
          database: database,
          sharedPreferences: await SharedPreferences.getInstance(),
        ),
        calculationService: BudgetCalculationService(),
      ),
    );
  });

  tearDown(() => database.close());

  test('create persists billId and the entity reads it back', () async {
    await repository.createExpense(expense(billId: 'bill-1'));

    expect(await storedBillId(), 'bill-1');
    expect((await repository.getExpenseById('e1'))!.billId, 'bill-1');
  });

  test('an edit in the same budget keeps bill_id', () async {
    await repository.createExpense(expense(billId: 'bill-1'));

    // The edit form builds a fresh entity: billId is null there.
    await repository.updateExpense(expense(amount: 210, note: 'edited'));

    final row = await database.select(database.expenses).getSingle();
    expect(row.amount, 210);
    expect(row.note, 'edited');
    expect(row.billId, 'bill-1');
  });

  test('an edit never writes a billId it carries', () async {
    await repository.createExpense(expense());

    await repository.updateExpense(expense(billId: 'bill-1'));

    expect(await storedBillId(), isNull);
  });

  test('moving to another budget clears bill_id', () async {
    await repository.createExpense(expense(billId: 'bill-1'));
    final stored = await repository.getExpenseById('e1');

    // The move paths copy the stored entity, billId included.
    await repository.updateExpense(stored!.copyWith(budgetId: 'b2'));

    final row = await database.select(database.expenses).getSingle();
    expect(row.budgetId, 'b2');
    expect(row.billId, isNull);
  });

  test('ExpenseEntity.copyWith keeps, sets and clears billId', () {
    final linked = expense(billId: 'bill-1');
    expect(linked.copyWith(amount: 5).billId, 'bill-1');
    expect(linked.copyWith(clearBillId: true).billId, isNull);
    expect(expense().copyWith(billId: 'bill-2').billId, 'bill-2');
    expect(linked, isNot(expense()));
  });
}
