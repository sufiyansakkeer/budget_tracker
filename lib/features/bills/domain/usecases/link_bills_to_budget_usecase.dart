import '../../../budget/domain/repository/budget_repository.dart';
import '../entities/bill_entity.dart';
import '../entities/bill_failure.dart';
import '../repository/bill_repository.dart';

/// Links bills to a budget so their upcoming occurrences are set aside from
/// it ("Link bills" on the dashboard).
///
/// All bills are linked in one transaction, or none are. The budget must
/// exist and not be archived, and every bill must be in the budget's
/// currency: amounts are never relabelled to another currency.
class LinkBillsToBudgetUseCase {
  final BillRepository _billRepository;
  final BudgetRepository _budgetRepository;
  final DateTime Function() _clock;

  LinkBillsToBudgetUseCase({
    required BillRepository billRepository,
    required BudgetRepository budgetRepository,
    DateTime Function()? clock,
  }) : _billRepository = billRepository,
       _budgetRepository = budgetRepository,
       _clock = clock ?? DateTime.now;

  /// Returns the linked bills (already-linked ones are left as they are and
  /// included).
  Future<BillResult<List<BillEntity>>> call({
    required String budgetId,
    required List<String> billIds,
  }) async {
    try {
      final budget = await _budgetRepository.getBudgetById(budgetId);
      if (budget == null || budget.isArchived) {
        return const BillError(
          BillFailure(
            type: BillErrorType.notFound,
            message: 'Budget not found',
          ),
        );
      }

      final bills = <BillEntity>[];
      for (final id in billIds.toSet()) {
        final bill = await _billRepository.getBillById(id);
        if (bill == null) {
          return const BillError(
            BillFailure(
              type: BillErrorType.notFound,
              message: 'Bill not found',
            ),
          );
        }
        if (bill.currency != budget.currency) {
          return BillError(
            BillFailure(
              type: BillErrorType.invalidInput,
              message:
                  '${bill.title} is in ${bill.currency}, but ${budget.name} '
                  'uses ${budget.currency}',
            ),
          );
        }
        bills.add(bill);
      }

      final now = _clock();
      final linked = [
        for (final bill in bills)
          bill.budgetId == budget.id
              ? bill
              : bill.copyWith(budgetId: budget.id, updatedAt: now),
      ];
      await _billRepository.transaction(() async {
        for (var i = 0; i < linked.length; i++) {
          if (!identical(linked[i], bills[i])) {
            await _billRepository.updateBill(linked[i]);
          }
        }
      });
      return BillSuccess(linked);
    } catch (e) {
      return BillError(
        BillFailure(
          type: BillErrorType.databaseFailure,
          message: 'Failed to link bills: ${e.toString()}',
        ),
      );
    }
  }
}
