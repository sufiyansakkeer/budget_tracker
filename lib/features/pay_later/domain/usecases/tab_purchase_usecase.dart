import 'dart:developer' as developer;

import '../../../../core/currency/money_math.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/repository/expense_repository.dart';
import '../../../expenses/domain/validators/expense_validator.dart';
import '../entities/pay_later_tab.dart';
import '../entities/payment_allocation.dart';
import '../entities/purchase_change_impact.dart';
import '../repository/pay_later_repository.dart';
import '../services/pay_later_allocator.dart';
import 'reconcile_tab_usecase.dart';

/// Purchases on a tab (spec §2, §5, §6): a purchase is an ordinary expense
/// plus a link to the tab, so it is counted once, by the existing expense
/// paths.
///
/// Each write is one transaction on the shared database: the expense write
/// (whose own transaction, with the budget's remaining amount, nests inside
/// it), the link change and the reconcile of every tab touched commit or
/// roll back together.
///
/// Callers notify `RefreshBuses.expenses` and `RefreshBuses.payLater` after
/// a successful write; this use case notifies nothing.
class TabPurchaseUseCase {
  final ExpenseRepository _expenseRepository;
  final BudgetRepository _budgetRepository;
  final PayLaterRepository _payLaterRepository;
  final ReconcileTabUseCase _reconcileTab;

  TabPurchaseUseCase({
    required ExpenseRepository expenseRepository,
    required BudgetRepository budgetRepository,
    required PayLaterRepository payLaterRepository,
    required ReconcileTabUseCase reconcileTab,
  }) : _expenseRepository = expenseRepository,
       _budgetRepository = budgetRepository,
       _payLaterRepository = payLaterRepository,
       _reconcileTab = reconcileTab;

  /// Records [expense] on tab [tabId]: the expense (and its budget's
  /// remaining amount), the link and the tab's reconcile, in one
  /// transaction. The tab must exist, not be archived and be in the
  /// budget's currency; a bill payment ([ExpenseEntity.billId]) is refused.
  Future<ExpenseResult<ExpenseEntity>> create(
    ExpenseEntity expense, {
    required String tabId,
  }) async {
    final invalid = ExpenseValidator.check(expense);
    if (invalid != null) return ExpenseError(invalid);

    try {
      final rejected = await _checkTab(expense, tabId: tabId, newLink: true);
      if (rejected != null) return ExpenseError(rejected);

      await _payLaterRepository.transaction(() async {
        await _expenseRepository.createExpense(expense);
        await _payLaterRepository.linkExpense(
          expenseId: expense.id,
          tabId: tabId,
        );
        await _reconcileTab(tabId);
      });
      return ExpenseSuccess(expense);
    } catch (e) {
      return _failure('Failed to save expense', e);
    }
  }

  /// Saves an edit of [expense], which ends up on tab [tabId] (null: not on
  /// a tab). A move between tabs, or Pay later turned off, unlinks it from
  /// the old tab (its allocations go with the link) and reconciles both
  /// tabs, with the expense update, in one transaction.
  ///
  /// The tab must be in the budget's currency; a tab it is newly moved to
  /// must also exist and not be archived. A purchase may stay on a tab that
  /// was archived since. A bill payment (the stored row or [expense] has a
  /// bill id) can't be put on a tab; with a null [tabId] it saves like any
  /// other expense.
  Future<ExpenseResult<ExpenseEntity>> update(
    ExpenseEntity expense, {
    required String? tabId,
  }) async {
    final invalid = ExpenseValidator.check(expense);
    if (invalid != null) return ExpenseError(invalid);

    try {
      final existing = await _expenseRepository.getExpenseById(expense.id);
      if (existing == null) return _expenseNotFound();

      final oldTabId = await _payLaterRepository.tabIdForExpense(expense.id);
      if (tabId != null) {
        // The stored row counts too: on a same-budget edit the expense
        // repository keeps the stored bill_id even when [expense] has none.
        if (existing.billId != null) return const ExpenseError(_billOnTab);
        final rejected = await _checkTab(
          expense,
          tabId: tabId,
          newLink: tabId != oldTabId,
        );
        if (rejected != null) return ExpenseError(rejected);
      }

      await _payLaterRepository.transaction(() async {
        await _expenseRepository.updateExpense(expense);
        if (oldTabId != tabId) {
          if (oldTabId != null) {
            await _payLaterRepository.unlinkExpense(expense.id);
          }
          if (tabId != null) {
            await _payLaterRepository.linkExpense(
              expenseId: expense.id,
              tabId: tabId,
            );
          }
        }
        for (final touched in {oldTabId, tabId}.nonNulls) {
          await _reconcileTab(touched);
        }
      });
      return ExpenseSuccess(expense);
    } catch (e) {
      return _failure('Failed to update expense', e);
    }
  }

  /// Deletes an expense. On a tab, its link and allocations go with it and
  /// the tab is reconciled, in the same transaction; the returned snapshot
  /// lets [restore] put it back. Null data for an expense on no tab.
  Future<ExpenseResult<TabLinkSnapshot?>> delete(String expenseId) async {
    if (expenseId.isEmpty) {
      return const ExpenseError(
        ExpenseFailure(
          type: ExpenseErrorType.invalidInput,
          message: 'Expense id cannot be empty',
        ),
      );
    }

    try {
      final existing = await _expenseRepository.getExpenseById(expenseId);
      if (existing == null) return _expenseNotFound();

      final snapshot = await _payLaterRepository.transaction(() async {
        final tabId = await _payLaterRepository.tabIdForExpense(expenseId);
        TabLinkSnapshot? snapshot;
        if (tabId != null) {
          snapshot = TabLinkSnapshot(
            tabId: tabId,
            allocations: [
              for (final allocation in await _payLaterRepository.allocationsOf(
                tabId,
              ))
                if (allocation.expenseId == expenseId) allocation,
            ],
          );
        }
        // The link and its allocations cascade with the expense.
        await _expenseRepository.deleteExpense(expenseId);
        if (tabId != null) await _reconcileTab(tabId);
        return snapshot;
      });
      return ExpenseSuccess(snapshot);
    } catch (e) {
      return _failure('Failed to delete expense', e);
    }
  }

  /// Undo of [delete]: re-creates [expense] and, when [link] is given and
  /// its tab still exists, the link and the snapshot's allocations whose
  /// payment still exists; the reconcile that follows trims any that no
  /// longer fit. One transaction.
  Future<ExpenseResult<ExpenseEntity>> restore(
    ExpenseEntity expense,
    TabLinkSnapshot? link,
  ) async {
    final invalid = ExpenseValidator.check(expense);
    if (invalid != null) return ExpenseError(invalid);

    try {
      await _payLaterRepository.transaction(() async {
        await _expenseRepository.createExpense(expense);
        if (link == null) return;
        final tabId = link.tabId;
        if (await _payLaterRepository.getTab(tabId) == null) return;

        await _payLaterRepository.linkExpense(
          expenseId: expense.id,
          tabId: tabId,
        );
        final paymentIds = {
          for (final payment in await _payLaterRepository.paymentsOf(tabId))
            payment.id,
        };
        final rows = [
          for (final allocation in link.allocations)
            if (allocation.expenseId == expense.id &&
                paymentIds.contains(allocation.paymentId))
              allocation,
        ];
        if (rows.isNotEmpty) {
          await _payLaterRepository.applyDiff(AllocationDiff(inserts: rows));
        }
        await _reconcileTab(tabId);
      });
      return ExpenseSuccess(expense);
    } catch (e) {
      return _failure('Failed to restore expense', e);
    }
  }

  /// The tab [expenseId] is on, or null. Throws on a database failure.
  Future<String?> tabIdFor(String expenseId) {
    return _payLaterRepository.tabIdForExpense(expenseId);
  }

  /// For the expense details row: the tab and how much has been paid on it.
  /// Null when the expense is on no tab. Throws on a database failure.
  Future<({PayLaterTab tab, double paid})?> tabInfoFor(String expenseId) async {
    final tabId = await _payLaterRepository.tabIdForExpense(expenseId);
    if (tabId == null) return null;
    final tab = await _payLaterRepository.getTab(tabId);
    if (tab == null) return null;
    final money = MoneyMath.forCurrency(tab.currency);
    final paid = money.sumUnits([
      for (final allocation in await _payLaterRepository.allocationsOf(tabId))
        if (allocation.expenseId == expenseId) allocation.amount,
    ]);
    return (tab: tab, paid: money.toAmount(paid));
  }

  /// Dry run of reconcile for an edit or a delete of a purchase on a tab
  /// (spec §5, "Never silent"); nothing is written.
  ///
  /// [deleting]: the purchase is deleted. Otherwise [newTabId] is the tab
  /// the purchase will be on after the edit (null: Pay later turned off)
  /// and [newAmount] its new amount (null: unchanged). Leaving the tab is
  /// treated as removing it from the tab.
  ///
  /// Null when the expense is on no tab. Throws on a database failure, so
  /// a caller never mistakes a failed read for "nothing paid".
  Future<PurchaseChangeImpact?> impactOf(
    String expenseId, {
    double? newAmount,
    String? newTabId,
    bool deleting = false,
  }) async {
    final tabId = await _payLaterRepository.tabIdForExpense(expenseId);
    if (tabId == null) return null;
    final tab = await _payLaterRepository.getTab(tabId);
    if (tab == null) return null;

    // Every row goes in: reconcile drops what is missing from its inputs.
    final purchases = await _payLaterRepository.purchasesOf(tabId);
    final payments = await _payLaterRepository.paymentsOf(tabId);
    final allocations = await _payLaterRepository.allocationsOf(tabId);
    if (!purchases.any((p) => p.id == expenseId)) return null;

    final removing = deleting || newTabId != tabId;
    final hypothetical = [
      for (final purchase in purchases)
        if (purchase.id != expenseId)
          purchase
        else if (!removing)
          purchase.copyWith(amount: newAmount ?? purchase.amount),
    ];
    final diff = PayLaterAllocator(currency: tab.currency).reconcile(
      purchases: hypothetical,
      payments: payments,
      allocations: allocations,
    );

    final money = MoneyMath.forCurrency(tab.currency);
    final before = _paidUnits(allocations, money);
    final after = _paidUnits(_applied(allocations, diff), money);

    final paidBefore = before[expenseId] ?? 0;
    final paidAfter = removing ? 0 : (after[expenseId] ?? 0);
    final freed = paidBefore > paidAfter ? paidBefore - paidAfter : 0;

    final movesTo = <(ExpenseEntity, double)>[];
    var moved = 0;
    // purchasesOf is oldest first, so this list is too.
    for (final purchase in purchases) {
      if (purchase.id == expenseId) continue;
      final gained = (after[purchase.id] ?? 0) - (before[purchase.id] ?? 0);
      if (gained <= 0) continue;
      moved += gained;
      movesTo.add((purchase, money.toAmount(gained)));
    }
    final credit = freed > moved ? freed - moved : 0;

    return PurchaseChangeImpact(
      paidOnIt: money.toAmount(freed),
      paidBefore: money.toAmount(paidBefore),
      movesTo: movesTo,
      becomesCredit: money.toAmount(credit),
      currency: tab.currency,
    );
  }

  /// Why [expense] can't be on tab [tabId], or null. [newLink]: the
  /// purchase is not on that tab yet, so an archived tab is refused.
  Future<ExpenseFailure?> _checkTab(
    ExpenseEntity expense, {
    required String tabId,
    required bool newLink,
  }) async {
    // Spec §6: an expense can't be both a bill payment and on a tab.
    if (expense.billId != null) return _billOnTab;
    final tab = await _payLaterRepository.getTab(tabId);
    if (tab == null) {
      return const ExpenseFailure(
        type: ExpenseErrorType.notFound,
        message: 'Tab not found',
      );
    }
    if (newLink && tab.isArchived) {
      return const ExpenseFailure(
        type: ExpenseErrorType.invalidInput,
        message: 'This tab is archived. Pick another tab.',
      );
    }
    final budget = await _budgetRepository.getBudgetById(expense.budgetId);
    if (budget == null) {
      return const ExpenseFailure(
        type: ExpenseErrorType.notFound,
        message: 'Budget not found',
      );
    }
    if (budget.currency != tab.currency) {
      return ExpenseFailure(
        type: ExpenseErrorType.invalidInput,
        message:
            'This tab is in ${tab.currency}. '
            'Pick a budget in ${tab.currency}.',
      );
    }
    return null;
  }

  static const _billOnTab = ExpenseFailure(
    type: ExpenseErrorType.invalidInput,
    message: "A bill payment can't go on a Pay later tab.",
  );

  /// [allocations] with [diff] applied (deletes, updates, inserts).
  static List<PaymentAllocation> _applied(
    List<PaymentAllocation> allocations,
    AllocationDiff diff,
  ) => [
    for (final allocation in allocations)
      if (!diff.deletes.contains(allocation.id))
        diff.updates.containsKey(allocation.id)
            ? allocation.copyWith(amount: diff.updates[allocation.id])
            : allocation,
    ...diff.inserts,
  ];

  /// Units paid on each purchase.
  static Map<String, int> _paidUnits(
    List<PaymentAllocation> allocations,
    MoneyMath money,
  ) {
    final paid = <String, int>{};
    for (final allocation in allocations) {
      final units = money.toUnits(allocation.amount);
      paid.update(
        allocation.expenseId,
        (v) => v + units,
        ifAbsent: () => units,
      );
    }
    return paid;
  }

  static ExpenseError<T> _expenseNotFound<T>() => ExpenseError(
    const ExpenseFailure(
      type: ExpenseErrorType.notFound,
      message: 'Expense not found',
    ),
  );

  static ExpenseError<T> _failure<T>(String what, Object e) {
    developer.log('$what: $e', name: 'TabPurchase');
    return ExpenseError(
      ExpenseFailure(
        type: ExpenseErrorType.databaseFailure,
        message: '$what: $e',
      ),
    );
  }
}
