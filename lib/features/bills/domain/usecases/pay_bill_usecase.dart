import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/repository/expense_repository.dart';
import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';
import 'mark_bill_paid_usecase.dart';

/// What [PayBillUseCase] recorded.
class BillPaymentOutcome extends Equatable {
  /// The bill after payment: advanced to its next due date (recurring) or
  /// marked paid (one-time).
  final BillEntity bill;

  /// The expense recorded for the payment.
  final ExpenseEntity expense;

  /// The budget the expense was recorded in.
  final BudgetEntity budget;

  const BillPaymentOutcome({
    required this.bill,
    required this.expense,
    required this.budget,
  });

  /// Whether the payment settled money that was set aside in [budget]
  /// (committed spending), rather than plain spending from it.
  bool get settledSetAside => expense.billId != null;

  @override
  List<Object?> get props => [bill, expense, budget];
}

/// Pays a bill's current occurrence and records it as an expense, all in one
/// transaction: the payment record, the bill advancing (or being marked
/// paid) and the expense are written together or not at all.
///
/// The expense goes to the budget the bill is linked to when that budget is
/// running today, not archived and in the bill's currency; otherwise to the
/// active budget under the same conditions. With neither, nothing is written
/// and an [BillErrorType.invalidInput] error is returned — an expense dated
/// outside its budget's period would be counted by no budget, and an amount
/// in another currency would be added unconverted.
///
/// The expense carries the bill's id (committed spending, so today's safe
/// amount does not drop) only when the occurrence was set aside in that same
/// budget: the budget is the linked one and the due date is on or before its
/// end. Every other payment is plain spending from the budget.
class PayBillUseCase {
  final BillRepository _billRepository;
  final BudgetRepository _budgetRepository;
  final ExpenseRepository _expenseRepository;
  final DateTime Function() _clock;

  /// Category every bill payment is recorded under.
  static const String categoryId = 'bills';

  PayBillUseCase({
    required BillRepository billRepository,
    required BudgetRepository budgetRepository,
    required ExpenseRepository expenseRepository,
    DateTime Function()? clock,
  }) : _billRepository = billRepository,
       _budgetRepository = budgetRepository,
       _expenseRepository = expenseRepository,
       _clock = clock ?? DateTime.now;

  Future<BillResult<BillPaymentOutcome>> call(String billId) async {
    try {
      final bill = await _billRepository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
        );
      }
      if (bill.isPaid) {
        return const BillError(
          BillFailure(
            type: BillErrorType.invalidInput,
            message: 'This bill is already paid',
          ),
        );
      }

      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      final target = await _targetBudget(bill, today);
      if (target == null) return _noBudgetError(bill);

      final payment = BillPaymentRecord(
        id: const Uuid().v4(),
        billId: bill.id,
        amount: bill.amount,
        currency: bill.currency,
        paidDate: now,
        createdAt: now,
      );
      final updatedBill = MarkBillPaidUseCase.settle(bill, now);
      final expense = ExpenseEntity(
        id: const Uuid().v4(),
        budgetId: target.id,
        amount: bill.amount,
        categoryId: categoryId,
        note: 'Bill: ${bill.title}',
        date: today,
        time: now,
        createdAt: now,
        updatedAt: now,
        billId: _wasSetAside(bill, target) ? bill.id : null,
      );

      // Atomic: payment record + bill update + expense. The expense
      // repository's own transaction nests inside this one (same database).
      await _billRepository.transaction(() async {
        await _billRepository.createBillPayment(payment);
        await _billRepository.updateBill(updatedBill);
        await _expenseRepository.createExpense(expense);
      });

      return BillSuccess(
        BillPaymentOutcome(bill: updatedBill, expense: expense, budget: target),
      );
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to pay bill: ${e.toString()}',
        ),
      );
    }
  }

  /// The budget a payment of [bill] made today would be recorded in, or an
  /// error when there is none (same rules as [call]). Lets a confirmation
  /// name the budget before anything is written.
  Future<BillResult<BudgetEntity>> targetBudgetFor(String billId) async {
    try {
      final bill = await _billRepository.getBillById(billId);
      if (bill == null) {
        return const BillError(
          BillFailure(type: BillErrorType.notFound, message: 'Bill not found'),
        );
      }
      final now = _clock();
      final target = await _targetBudget(
        bill,
        DateTime(now.year, now.month, now.day),
      );
      if (target == null) return _noBudgetError(bill);
      return BillSuccess(target);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to find a budget for this bill: ${e.toString()}',
        ),
      );
    }
  }

  /// The linked budget if it can take the payment today, else the active
  /// budget if it can, else null.
  Future<BudgetEntity?> _targetBudget(BillEntity bill, DateTime today) async {
    final linkedId = bill.budgetId;
    if (linkedId != null) {
      final linked = await _budgetRepository.getBudgetById(linkedId);
      if (_canTake(linked, bill, today)) return linked;
    }
    final active = await _budgetRepository.getActiveBudget();
    if (_canTake(active, bill, today)) return active;
    return null;
  }

  static bool _canTake(BudgetEntity? budget, BillEntity bill, DateTime today) =>
      budget != null &&
      !budget.isArchived &&
      budget.isActiveOn(today) &&
      budget.currency == bill.currency;

  /// Whether the occurrence being paid was deducted from [target] as an
  /// upcoming bill: linked to it, and due on or before its end (overdue
  /// occurrences from before its start are carried into a running budget).
  static bool _wasSetAside(BillEntity bill, BudgetEntity target) {
    if (bill.budgetId != target.id) return false;
    final due = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    final end = DateTime(
      target.endDate.year,
      target.endDate.month,
      target.endDate.day,
    );
    return !due.isAfter(end);
  }

  static BillError<T> _noBudgetError<T>(BillEntity bill) => BillError(
    BillFailure(
      type: BillErrorType.invalidInput,
      message: 'No running budget in ${bill.currency} to record this payment',
    ),
  );
}
