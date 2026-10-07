import 'dart:developer' as developer;

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/repository/bill_repository.dart';
import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/entities/monthly_statistics_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import '../../../budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/services/safe_to_spend_calculator.dart';
import '../entities/committed_spending.dart';
import '../repository/dashboard_repository.dart';
import '../services/bill_occurrence_enumerator.dart';

/// Today's Safe Spending for budgets, with upcoming bills, money kept aside
/// and the savings goal protected.
///
/// Gathers the inputs (SQL period totals, committed bill payments, unpaid
/// bills) and hands them to [SafeToSpendCalculator]. Every surface that shows
/// a daily amount reads the entity this produces, so the number is the same
/// everywhere.
///
/// "Today" is taken once per call ([referenceDate] or the injected clock,
/// time of day stripped) and used for every budget.
class GetSafeToSpendUseCase {
  final BudgetRepository _budgetRepository;
  final BillRepository _billRepository;
  final DashboardRepository _dashboardRepository;
  final BillOccurrenceEnumerator _enumerator;
  final SafeToSpendCalculator _calculator;
  final DateTime Function() _clock;

  GetSafeToSpendUseCase({
    required BudgetRepository budgetRepository,
    required BillRepository billRepository,
    required DashboardRepository dashboardRepository,
    required SafeToSpendCalculator calculator,
    BillOccurrenceEnumerator enumerator = const BillOccurrenceEnumerator(),
    DateTime Function()? clock,
  }) : _budgetRepository = budgetRepository,
       _billRepository = billRepository,
       _dashboardRepository = dashboardRepository,
       _calculator = calculator,
       _enumerator = enumerator,
       _clock = clock ?? DateTime.now;

  /// Safe-to-spend for one budget in any phase (running, not started,
  /// ended).
  Future<BudgetResult<SafeToSpendEntity>> call({
    required String budgetId,
    DateTime? referenceDate,
  }) async {
    final budget = await _budgetRepository.getBudgetById(budgetId);
    if (budget == null) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.notFound,
          message: 'Budget not found',
        ),
      );
    }
    final results = await callForBudgets([
      budget,
    ], referenceDate: referenceDate ?? _clock());
    final result = results[budget.id];
    if (result == null) {
      return const BudgetError(
        BudgetFailure(
          type: BudgetErrorType.invalidBudget,
          message: "This budget's figures couldn't be calculated",
        ),
      );
    }
    return BudgetSuccess(result);
  }

  /// Safe-to-spend for each of [budgets], keyed by budget id, with one bills
  /// read and one committed-spending read for all of them. Each budget is
  /// evaluated on its own data only; amounts are never pooled.
  ///
  /// [allBudgets] (every known budget, archived included) is used to tell
  /// whether a bill linked to another budget is set aside there; it is read
  /// from the repository when omitted.
  ///
  /// If the bills cannot be read, every result reports its bills as
  /// unavailable (no deduction, status capped) instead of failing.
  ///
  /// A budget whose own data cannot be evaluated (e.g. an amount beyond
  /// what `MoneyMath` accepts) is left out of the map instead of failing
  /// the whole call, so it never takes the other budgets' figures with it.
  Future<Map<String, SafeToSpendEntity>> callForBudgets(
    List<BudgetEntity> budgets, {
    required DateTime referenceDate,
    List<BudgetEntity>? allBudgets,
  }) async {
    if (budgets.isEmpty) return const {};
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    final bills = await _readBills();
    final budgetsById = <String, BudgetEntity>{
      if (bills != null)
        for (final b in allBudgets ?? await _budgetRepository.getAllBudgets())
          b.id: b,
      for (final b in budgets) b.id: b,
    };
    final committed = await _dashboardRepository.getCommittedSpending(
      budgets: budgets,
      today: today,
    );

    final results = <String, SafeToSpendEntity>{};
    for (final budget in budgets) {
      final statistics = await _budgetRepository.getBudgetStatistics(
        budget.id,
        referenceDate: today,
      );
      final paid = committed[budget.id] ?? CommittedSpending.zero;
      try {
        results[budget.id] = _evaluate(
          budget,
          statistics: statistics,
          paid: paid,
          bills: bills,
          budgetsById: budgetsById,
          today: today,
        );
      } catch (error, stackTrace) {
        developer.log(
          '[SafeToSpend] Could not evaluate budget ${budget.id}',
          name: 'SafeToSpend',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return results;
  }

  /// The pure part for one budget: its bill commitments and the engine.
  SafeToSpendEntity _evaluate(
    BudgetEntity budget, {
    required MonthlyStatisticsEntity statistics,
    required CommittedSpending paid,
    required List<BillEntity>? bills,
    required Map<String, BudgetEntity> budgetsById,
    required DateTime today,
  }) {
    final commitments = bills == null
        ? null
        : _enumerator.forBudget(
            budget: budget,
            bills: bills,
            budgetsById: budgetsById,
            today: today,
          );

    return _calculator.calculate(
      SafeToSpendInput(
        budgetId: budget.id,
        budgetName: budget.name,
        currency: budget.currency,
        startDate: budget.startDate,
        endDate: budget.endDate,
        today: today,
        budgetAmount: budget.monthlyAmount,
        periodSpent: statistics.totalSpent,
        // The statistics' today total is not clipped to the period.
        todaySpent: budget.isActiveOn(today) ? statistics.todaySpending : 0,
        committedSpentInPeriod: paid.periodTotal,
        committedSpentToday: paid.todayTotal,
        commitments: commitments?.occurrences,
        currencyExcluded:
            commitments?.currencyExcluded ?? CurrencyExcludedSummary.none,
        unlinked: commitments?.unlinked ?? UnlinkedCommitmentSummary.none,
        reservedAmount: budget.reservedAmount,
        savingsTarget: budget.savingsTarget,
      ),
    );
  }

  /// All bills, or null when they cannot be read (reported as unavailable).
  Future<List<BillEntity>?> _readBills() async {
    try {
      return await _billRepository.getBills();
    } catch (_) {
      return null;
    }
  }
}
