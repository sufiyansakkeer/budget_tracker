import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/repository/bill_repository.dart';
import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../services/bill_occurrence_enumerator.dart';

/// The bills the "Link bills" sheet offers for one budget.
class LinkableBills extends Equatable {
  final BudgetEntity budget;

  /// In the budget's currency, due before its end and set aside by no
  /// budget: exactly the bills counted in the budget's "not linked"
  /// disclosure. Soonest due first.
  final List<BillEntity> linkable;

  /// The same kind of bills in another currency. Shown, never linked: a
  /// link would relabel the amount without converting it.
  final List<BillEntity> otherCurrency;

  const LinkableBills({
    required this.budget,
    required this.linkable,
    required this.otherCurrency,
  });

  @override
  List<Object?> get props => [budget, linkable, otherCurrency];
}

/// Finds the bills that could be linked to a budget so their upcoming
/// occurrences are set aside from it. Uses the same rules as the
/// safe-to-spend disclosure ([BillOccurrenceEnumerator.billsNotSetAside]),
/// so the sheet lists exactly what the dashboard warned about.
///
/// A bills read failure is thrown, not swallowed: the sheet reports it.
class GetLinkableBillsUseCase {
  final BillRepository _billRepository;
  final BudgetRepository _budgetRepository;
  final BillOccurrenceEnumerator _enumerator;
  final DateTime Function() _clock;

  GetLinkableBillsUseCase({
    required BillRepository billRepository,
    required BudgetRepository budgetRepository,
    BillOccurrenceEnumerator enumerator = const BillOccurrenceEnumerator(),
    DateTime Function()? clock,
  }) : _billRepository = billRepository,
       _budgetRepository = budgetRepository,
       _enumerator = enumerator,
       _clock = clock ?? DateTime.now;

  Future<BudgetResult<LinkableBills>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    final budget = await _budgetRepository.getBudgetById(budgetId);
    if (budget == null || budget.isArchived) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.notFound,
          message: 'Budget not found',
        ),
      );
    }
    final now = referenceDate ?? _clock();
    final today = DateTime(now.year, now.month, now.day);
    final bills = await _billRepository.getBills();
    final budgets = await _budgetRepository.getAllBudgets();
    final candidates = _enumerator.billsNotSetAside(
      budget: budget,
      bills: bills,
      budgetsById: {for (final b in budgets) b.id: b, budget.id: budget},
      today: today,
    );
    return BudgetSuccess(
      LinkableBills(
        budget: budget,
        linkable: [
          for (final bill in candidates)
            if (bill.currency == budget.currency) bill,
        ],
        otherCurrency: [
          for (final bill in candidates)
            if (bill.currency != budget.currency) bill,
        ],
      ),
    );
  }
}
