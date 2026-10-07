import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/repository/bill_repository.dart';
import 'package:monivo/features/bills/domain/usecases/create_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/delete_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/get_bill_by_id_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/get_bills_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_paid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_unpaid_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/pay_bill_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/schedule_bill_reminder_usecase.dart';
import 'package:monivo/features/bills/domain/usecases/update_bill_usecase.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/budget_filter.dart';
import 'package:monivo/features/budget/domain/entities/monthly_statistics_entity.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';

import 'bill_payment_fakes.dart';

/// Budgets held in a list, for screens that list or name budgets (bill
/// form picker, bill details, budget screens). Records updates.
class ListBudgetRepository implements BudgetRepository {
  final List<BudgetEntity> budgets;
  String? activeId;
  bool throwOnRead = false;
  final List<BudgetEntity> updated = [];

  ListBudgetRepository([List<BudgetEntity>? budgets, this.activeId])
    : budgets = List.of(budgets ?? const []);

  BudgetEntity? _find(String id) {
    for (final b in budgets) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

  @override
  Future<BudgetEntity?> getActiveBudget() async =>
      activeId == null ? null : _find(activeId!);

  @override
  Future<String?> getActiveBudgetId() async => activeId;

  @override
  Future<void> setActiveBudgetId(String budgetId) async => activeId = budgetId;

  @override
  Future<BudgetEntity?> getBudgetById(String id) async => _find(id);

  @override
  Future<List<BudgetEntity>> getAllBudgets({
    BudgetQueryOptions? options,
  }) async {
    if (throwOnRead) throw Exception('budgets unavailable');
    return List.of(budgets);
  }

  @override
  Future<BudgetEntity> createBudget(BudgetEntity budget) async {
    budgets.add(budget);
    return budget;
  }

  @override
  Future<BudgetEntity> updateBudget(BudgetEntity budget) async {
    budgets.removeWhere((b) => b.id == budget.id);
    budgets.add(budget);
    updated.add(budget);
    return budget;
  }

  @override
  Future<void> deleteBudget(String id) async =>
      budgets.removeWhere((b) => b.id == id);

  @override
  Future<BudgetEntity> setBudgetArchived(
    String id, {
    required bool archived,
  }) async {
    final budget = _find(id)!.copyWith(isArchived: archived);
    return updateBudget(budget);
  }

  @override
  Future<BudgetEntity> duplicateBudget(
    String id, {
    required String newName,
    DateTime? startDate,
    DateTime? endDate,
  }) async => throw UnimplementedError();

  @override
  Future<MonthlyStatisticsEntity> getBudgetStatistics(
    String budgetId, {
    DateTime? referenceDate,
  }) async => MonthlyStatisticsEntity.empty;

  @override
  Future<double> getTodaySpending(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 0;

  @override
  Future<int> getRemainingDays(
    String budgetId, {
    DateTime? referenceDate,
  }) async => 1;

  @override
  Future<BudgetResult<BudgetCalculationContext>> getCalculationContext(
    String budgetId, {
    DateTime? referenceDate,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateBudgetRemainingAmount(String budgetId) async {}

  @override
  Future<double> getExpensesTotalInRange(
    String budgetId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async => 0;
}

/// Reminders that do nothing (no notification plugin in widget tests).
class NoopBillReminderService extends BillReminderService {
  NoopBillReminderService(BillRepository repository)
    : super(repository: repository);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleReminder(BillEntity bill) async {}

  @override
  Future<void> cancelReminder(BillEntity bill) async {}

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;
}

/// A [BillBloc] on real bill use cases over [repository]. Payments with an
/// expense go to [payBill] (by default a fake that must not be called).
BillBloc buildTestBillBloc(
  BillRepository repository, {
  PayBillUseCase? payBill,
  ExpenseRepository? expenses,
}) {
  return BillBloc(
    createBillUseCase: CreateBillUseCase(repository: repository),
    updateBillUseCase: UpdateBillUseCase(repository: repository),
    deleteBillUseCase: DeleteBillUseCase(repository: repository),
    getBillsUseCase: GetBillsUseCase(repository: repository),
    getBillByIdUseCase: GetBillByIdUseCase(repository: repository),
    markBillPaidUseCase: MarkBillPaidUseCase(repository: repository),
    markBillUnpaidUseCase: MarkBillUnpaidUseCase(
      repository: repository,
      expenseRepository: expenses ?? InMemoryExpenseRepository(),
    ),
    payBillUseCase:
        payBill ??
        FakePayBillUseCase(
          const BillError(
            BillFailure(type: BillErrorType.invalidInput, message: 'unused'),
          ),
        ),
    reminderService: NoopBillReminderService(repository),
  );
}
