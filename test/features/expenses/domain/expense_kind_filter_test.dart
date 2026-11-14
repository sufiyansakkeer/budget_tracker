import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/domain/usecases/filter_expenses_usecase.dart';

void main() {
  final day = DateTime(2026, 10, 8);
  ExpenseEntity e(String id, {String? billId}) => ExpenseEntity(
    id: id,
    budgetId: 'b',
    amount: 10,
    categoryId: 'food',
    date: day,
    time: day,
    createdAt: day,
    updatedAt: day,
    billId: billId,
  );
  final all = [e('lunch'), e('rent', billId: 'r1'), e('fuel')];
  const filter = FilterExpensesUseCase();

  test('All keeps everything; the kind alone makes a filter active', () {
    const none = ExpenseHistoryFilter();
    expect(none.kind, ExpenseKind.all);
    expect(none.isActive, isFalse);
    expect(none.copyWithKind(ExpenseKind.bills).isActive, isTrue);
  });

  test('Expenses leaves bill payments out; Bills keeps only them', () {
    List<String> ids(ExpenseKind k) => [
      for (final x in filter(
        expenses: all,
        filter: const ExpenseHistoryFilter().copyWithKind(k),
      ))
        x.id,
    ];
    expect(ids(ExpenseKind.expenses), ['lunch', 'fuel']);
    expect(ids(ExpenseKind.bills), ['rent']);
    expect(ids(ExpenseKind.all), ['lunch', 'rent', 'fuel']);
  });

  test('Pay later keeps only tab purchases; Budgets keeps no expense', () {
    List<String> ids(ExpenseKind k) => [
      for (final x in filter(
        expenses: all,
        filter: const ExpenseHistoryFilter().copyWithKind(k),
        tabPurchaseIds: const {'fuel'},
      ))
        x.id,
    ];
    expect(ids(ExpenseKind.payLater), ['fuel']);
    expect(ids(ExpenseKind.budgets), isEmpty);
    expect(ids(ExpenseKind.all), ['lunch', 'rent', 'fuel']);
  });

  test('other filters keep the kind', () {
    final f = const ExpenseHistoryFilter()
        .copyWithKind(ExpenseKind.bills)
        .copyWithCategory('food')
        .copyWithReceiptOnly(false);
    expect(f.kind, ExpenseKind.bills);
  });
}
