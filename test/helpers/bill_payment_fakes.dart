import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';

/// In-memory expenses for bill use cases that create or delete the expense
/// recording a bill payment.
class InMemoryExpenseRepository implements ExpenseRepository {
  final Map<String, ExpenseEntity> store = {};
  final List<String> deletedIds = [];

  InMemoryExpenseRepository([List<ExpenseEntity> expenses = const []]) {
    for (final e in expenses) {
      store[e.id] = e;
    }
  }

  @override
  Future<void> createExpense(ExpenseEntity expense) async =>
      store[expense.id] = expense;

  @override
  Future<void> updateExpense(ExpenseEntity expense) async =>
      store[expense.id] = expense;

  @override
  Future<void> deleteExpense(String id) async {
    store.remove(id);
    deletedIds.add(id);
  }

  @override
  Future<ExpenseEntity?> getExpenseById(String id) async => store[id];

  @override
  Future<List<ExpenseEntity>> getExpenses({
    String? budgetId,
    int? month,
    int? year,
    DateTime? from,
    DateTime? to,
  }) async {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    return store.values.where((e) {
      if (budgetId != null && e.budgetId != budgetId) return false;
      if (from != null && day(e.date).isBefore(day(from))) return false;
      if (to != null && day(e.date).isAfter(day(to))) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<ExpenseEntity>> getExpensesForBudgets({
    required List<String> budgetIds,
  }) async =>
      store.values.where((e) => budgetIds.contains(e.budgetId)).toList();

  @override
  Future<List<ExpenseEntity>> getExpensesForBill(String billId) async =>
      store.values.where((e) => e.billId == billId).toList();

  @override
  Future<List<ExpenseCategory>> getCategories() async => const [];
}

/// Returns [result] for every payment and records the bill ids it was asked
/// to pay; for BillBloc tests that only check the wiring. [target] answers
/// [targetBudgetFor] (for confirmation dialogs); unset, it throws.
class FakePayBillUseCase implements PayBillUseCase {
  BillResult<BillPaymentOutcome> result;
  BillResult<BudgetEntity>? target;
  final List<String> paidBillIds = [];

  FakePayBillUseCase(this.result, {this.target});

  @override
  Future<BillResult<BillPaymentOutcome>> call(String billId) async {
    paidBillIds.add(billId);
    return result;
  }

  @override
  Future<BillResult<BudgetEntity>> targetBudgetFor(String billId) async =>
      target ?? (throw UnimplementedError());
}
