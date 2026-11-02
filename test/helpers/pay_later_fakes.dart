import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_allocator.dart';
import 'package:monivo/features/pay_later/domain/services/pay_later_ledger.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tabs_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_purchase_usecase.dart';

/// A [TabPurchaseUseCase] that records every call and writes nothing.
///
/// By default no expense is on a tab ([tabIdFor] returns null) and every
/// write succeeds, so a bloc built with it behaves exactly as before Pay
/// Later for every expense not put on a tab.
class FakeTabPurchaseUseCase implements TabPurchaseUseCase {
  /// Every call, in order, e.g. `create:e1:t1`, `tabIdFor:e1`.
  final List<String> calls = [];

  /// The tab each expense is on, for [tabIdFor] and [delete].
  final Map<String, String> tabIds = {};

  /// Makes [tabIdFor] throw, as when the database can't be read.
  Object? tabIdForError;

  /// Makes every write return this failure.
  ExpenseFailure? failWrites;

  /// What [tabInfoFor] answers, by expense id (absent: on no tab).
  final Map<String, ({PayLaterTab tab, double paid})> tabInfos = {};

  /// Makes [tabInfoFor] throw.
  Object? tabInfoError;

  /// What [impactOf] answers for each call; null (the default) answers
  /// null, as for an expense on no tab.
  PurchaseChangeImpact? Function(ImpactQuery query)? impactFor;

  /// Every [impactOf] call's arguments, in order.
  final List<ImpactQuery> impactQueries = [];

  /// Makes [impactOf] throw, as when the database can't be read.
  Object? impactError;

  /// When set, [impactOf] waits for it before answering (a slow read).
  Future<void>? impactGate;

  /// What [delete] puts in its snapshot for a purchase on a tab.
  TabLinkSnapshot Function(String expenseId, String tabId) snapshotFor =
      (_, tabId) => TabLinkSnapshot(tabId: tabId, allocations: const []);

  @override
  Future<ExpenseResult<ExpenseEntity>> create(
    ExpenseEntity expense, {
    required String tabId,
  }) async {
    calls.add('create:${expense.id}:$tabId');
    final failure = failWrites;
    if (failure != null) return ExpenseError(failure);
    tabIds[expense.id] = tabId;
    return ExpenseSuccess(expense);
  }

  @override
  Future<ExpenseResult<ExpenseEntity>> update(
    ExpenseEntity expense, {
    required String? tabId,
  }) async {
    calls.add('update:${expense.id}:$tabId');
    final failure = failWrites;
    if (failure != null) return ExpenseError(failure);
    if (tabId == null) {
      tabIds.remove(expense.id);
    } else {
      tabIds[expense.id] = tabId;
    }
    return ExpenseSuccess(expense);
  }

  @override
  Future<ExpenseResult<TabLinkSnapshot?>> delete(String expenseId) async {
    calls.add('delete:$expenseId');
    final failure = failWrites;
    if (failure != null) return ExpenseError(failure);
    final tabId = tabIds.remove(expenseId);
    return ExpenseSuccess(tabId == null ? null : snapshotFor(expenseId, tabId));
  }

  @override
  Future<ExpenseResult<ExpenseEntity>> restore(
    ExpenseEntity expense,
    TabLinkSnapshot? link,
  ) async {
    calls.add('restore:${expense.id}:${link?.tabId}');
    final failure = failWrites;
    if (failure != null) return ExpenseError(failure);
    if (link != null) tabIds[expense.id] = link.tabId;
    return ExpenseSuccess(expense);
  }

  @override
  Future<String?> tabIdFor(String expenseId) async {
    calls.add('tabIdFor:$expenseId');
    final error = tabIdForError;
    if (error != null) throw error;
    return tabIds[expenseId];
  }

  @override
  Future<({PayLaterTab tab, double paid})?> tabInfoFor(String expenseId) async {
    calls.add('tabInfoFor:$expenseId');
    final error = tabInfoError;
    if (error != null) throw error;
    return tabInfos[expenseId];
  }

  @override
  Future<PurchaseChangeImpact?> impactOf(
    String expenseId, {
    double? newAmount,
    String? newTabId,
    bool deleting = false,
  }) async {
    calls.add('impactOf:$expenseId');
    final query = (
      expenseId: expenseId,
      newAmount: newAmount,
      newTabId: newTabId,
      deleting: deleting,
    );
    impactQueries.add(query);
    final gate = impactGate;
    if (gate != null) await gate;
    final error = impactError;
    if (error != null) throw error;
    return impactFor?.call(query);
  }
}

/// The arguments of one [TabPurchaseUseCase.impactOf] call.
typedef ImpactQuery = ({
  String expenseId,
  double? newAmount,
  String? newTabId,
  bool deleting,
});

/// A [GetTabsUseCase] over a list the test controls.
class FakeGetTabsUseCase implements GetTabsUseCase {
  /// Every tab, archived included, as the repository returns them.
  final List<PayLaterTab> tabs;

  /// Makes the next calls fail with a database failure.
  bool fail = false;

  /// How many times the tabs were read.
  int calls = 0;

  FakeGetTabsUseCase([List<PayLaterTab>? tabs]) : tabs = tabs ?? [];

  @override
  Future<PayLaterResult<List<PayLaterTab>>> call() async {
    calls++;
    if (fail) {
      return const PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.databaseFailure,
          message: 'Failed to load tabs: disk I/O',
        ),
      );
    }
    return PayLaterSuccess(List.of(tabs));
  }
}

/// A [ReconcileTabUseCase] with no database: reconciles record the tab and
/// write nothing, and [aroundBudgetDelete] just runs the delete.
class FakeReconcileTabUseCase implements ReconcileTabUseCase {
  /// Every call, in order, e.g. `call:t1`, `all`, `aroundBudgetDelete:b1`.
  final List<String> calls = [];

  /// What [countPurchasesInBudget] answers for any budget.
  int purchasesInBudget = 0;

  /// Makes [countPurchasesInBudget] throw, as when the database can't be
  /// read.
  Object? countError;

  @override
  Future<void> call(String tabId) async => calls.add('call:$tabId');

  @override
  Future<void> all() async => calls.add('all');

  @override
  Future<T> aroundBudgetDelete<T>(
    String budgetId,
    Future<T> Function() delete,
  ) {
    calls.add('aroundBudgetDelete:$budgetId');
    return delete();
  }

  @override
  Future<int> countPurchasesInBudget(String budgetId) async {
    calls.add('countPurchasesInBudget:$budgetId');
    final error = countError;
    if (error != null) throw error;
    return purchasesInBudget;
  }
}

/// A [GetTabLedgerUseCase] with no database: builds each tab's ledger from
/// the purchases and payments the test gives it, with allocations worked out
/// by the real allocator (FIFO), exactly as a reconciled database holds them.
class FakeGetTabLedgerUseCase implements GetTabLedgerUseCase {
  /// The tabs it knows, shared with a [FakeGetTabsUseCase] when both are
  /// used together.
  final List<PayLaterTab> tabs;
  final DateTime Function() clock;

  /// Purchases by tab id.
  final Map<String, List<ExpenseEntity>> purchases = {};

  /// Payments by tab id.
  final Map<String, List<TabPayment>> payments = {};

  /// Tab ids whose ledger fails with a database failure.
  final Set<String> failing = {};

  FakeGetTabLedgerUseCase({required this.tabs, required this.clock});

  @override
  Future<PayLaterResult<TabLedger>> call(String tabId) async {
    if (failing.contains(tabId)) {
      return const PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.databaseFailure,
          message: 'Failed to load tab: disk I/O',
        ),
      );
    }
    final tab = tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) {
      return const PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.notFound,
          message: 'Tab not found',
        ),
      );
    }
    final bought = purchases[tabId] ?? const <ExpenseEntity>[];
    final paid = payments[tabId] ?? const <TabPayment>[];
    final diff = PayLaterAllocator(
      currency: tab.currency,
    ).reconcile(purchases: bought, payments: paid, allocations: const []);
    return PayLaterSuccess(
      PayLaterLedger.build(
        tab: tab,
        purchases: bought,
        payments: paid,
        allocations: diff.inserts,
        today: clock(),
      ),
    );
  }
}
