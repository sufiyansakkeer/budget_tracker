import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../pay_later/domain/entities/purchase_change_impact.dart';
import '../../../pay_later/domain/usecases/tab_purchase_usecase.dart';
import '../expense_failure_copy.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_failure.dart';
import '../../domain/usecases/create_expense_usecase.dart';
import '../../domain/usecases/delete_expense_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_expense_by_id_usecase.dart';
import '../../domain/usecases/get_expenses_usecase.dart';
import '../../domain/usecases/rank_categories_by_use_usecase.dart';
import '../../domain/usecases/update_expense_usecase.dart';
import '../../../../core/events/refresh_bus.dart';
import 'expense_event.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  /// Shown when an expense can't be read (not when it no longer exists).
  static const openFailedMessage = "Couldn't open this expense. Try again.";

  final CreateExpenseUseCase createExpenseUseCase;
  final UpdateExpenseUseCase updateExpenseUseCase;
  final DeleteExpenseUseCase deleteExpenseUseCase;
  final GetExpenseByIdUseCase getExpenseByIdUseCase;
  final GetExpensesUseCase getExpensesUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;
  final BudgetRepository budgetRepository;
  final RankCategoriesByUseUseCase rankCategoriesByUse;

  /// Purchases on Pay later tabs. Only an event that names a tab (or an
  /// edit or delete of an expense already on one) goes through it; "Now"
  /// expenses keep their exact path.
  final TabPurchaseUseCase tabPurchases;

  ExpenseBloc({
    required this.createExpenseUseCase,
    required this.updateExpenseUseCase,
    required this.deleteExpenseUseCase,
    required this.getExpenseByIdUseCase,
    required this.getExpensesUseCase,
    required this.getCategoriesUseCase,
    required this.budgetRepository,
    required this.tabPurchases,
    this.rankCategoriesByUse = const RankCategoriesByUseUseCase(),
  }) : super(const ExpenseState()) {
    on<ExpenseLoadCategories>(_onLoadCategories);
    on<ExpenseLoadQuickAdd>(_onLoadQuickAdd);
    on<ExpenseInitialize>(_onInitialize);
    on<ExpenseLoadById>(_onLoadById);
    on<ExpenseCreate>(_onCreate);
    on<ExpenseUpdate>(_onUpdate);
    on<ExpenseDelete>(_onDelete);
    on<ExpenseRestore>(_onRestore);
    on<ExpenseClearMessage>(_onClearMessage);
  }

  Future<void> _onLoadCategories(
    ExpenseLoadCategories event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state.categories.isNotEmpty) return;

    final result = await getCategoriesUseCase();
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(state.copyWith(categories: data));
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            message: failure.shown("Couldn't load your categories. Try again."),
          ),
        );
    }
  }

  /// Reads the active budget and ranks the categories by use. Without a
  /// budget the sheet says so, and without history the shortcuts fall back
  /// to catalogue order. A budget or categories that can't be read leave the
  /// load [QuickAddLoad.failed], so the sheet offers a retry rather than
  /// claiming there is no budget.
  Future<void> _onLoadQuickAdd(
    ExpenseLoadQuickAdd event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(quickAddLoad: QuickAddLoad.loading));

    var failed = false;
    var categories = state.categories;
    if (categories.isEmpty) {
      final result = await getCategoriesUseCase();
      switch (result) {
        case ExpenseSuccess(:final data):
          categories = data;
        case ExpenseError(:final failure):
          debugPrint(
            '[error] Loading categories for quick add: ${failure.message}',
          );
          failed = true;
      }
    }

    BudgetEntity? budget;
    try {
      final id = await budgetRepository.getActiveBudgetId();
      budget = id == null ? null : await budgetRepository.getBudgetById(id);
    } catch (e) {
      debugPrint('[error] Loading the active budget for quick add: $e');
      failed = true;
    }
    if (budget?.isArchived ?? false) budget = null;

    final now = event.now ?? DateTime.now();
    final from = DateTime(now.year, now.month, now.day - event.days);
    final recent = await getExpensesUseCase(from: from, to: now);
    final expenses = switch (recent) {
      ExpenseSuccess(:final data) => data,
      ExpenseError() => const <ExpenseEntity>[],
    };

    emit(
      state.copyWith(
        categories: categories,
        quickAddLoad: failed ? QuickAddLoad.failed : QuickAddLoad.loaded,
        quickAddBudget: budget,
        clearQuickAddBudget: budget == null,
        frequentCategories: rankCategoriesByUse(
          categories: categories,
          expenses: expenses,
        ),
      ),
    );
  }

  /// Captures the current date/time once (from a single [DateTime.now()] call)
  /// and stores them in state as the Add Expense form's defaults. This avoids
  /// separate `now()` calls that could straddle midnight.
  Future<void> _onInitialize(
    ExpenseInitialize event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state.initialDate != null && state.initialTime != null) return;

    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    emit(state.copyWith(initialDate: date, initialTime: now));
  }

  Future<String?> _resolveActiveBudgetId() async {
    try {
      return await budgetRepository.getActiveBudgetId();
    } catch (e) {
      debugPrint('[error] Reading the active budget: $e');
      return null;
    }
  }

  /// Resolves the effective budget id for an expense during creation.
  /// Prefers the expense's own budgetId; otherwise uses the active budget id.
  ///
  /// If budgetId cannot be resolved, returns an error result instead of
  /// silently returning an expense with empty budgetId (which would violate
  /// database constraints and make the expense invisible).
  Future<ExpenseEntity?> _ensureBudgetId(ExpenseEntity expense) async {
    if (expense.budgetId.isNotEmpty) return expense;

    final id = await _resolveActiveBudgetId();
    if (id == null || id.isEmpty) {
      // Cannot proceed without a valid budget ID
      return null;
    }

    return expense.copyWith(budgetId: id);
  }

  Future<void> _onLoadById(
    ExpenseLoadById event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.loading));

    final result = await getExpenseByIdUseCase(event.id);
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(state.copyWith(status: ExpenseBlocStatus.loaded, expense: data));
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.shown(openFailedMessage),
          ),
        );
    }
  }

  Future<void> _onCreate(
    ExpenseCreate event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.creating));

    final expense = await _ensureBudgetId(event.expense);
    if (expense == null) {
      emit(
        state.copyWith(
          status: ExpenseBlocStatus.error,
          message: 'No active budget selected. Please select a budget first.',
        ),
      );
      return;
    }

    final tabId = event.tabId;
    final result = tabId == null
        ? await createExpenseUseCase(expense)
        : await tabPurchases.create(expense, tabId: tabId);
    switch (result) {
      case ExpenseSuccess():
        RefreshBuses.expenses.notifyChanged();
        if (tabId != null) RefreshBuses.payLater.notifyChanged();
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            expense: event.expense,
            message: 'Expense added successfully',
            lastAction: ExpenseAction.created,
            clearLastDeleted: true,
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.shown("Couldn't save the expense. Try again."),
          ),
        );
    }
  }

  Future<void> _onUpdate(
    ExpenseUpdate event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.updating));

    final onTab = event.tabId != null || event.wasOnTab;
    final result = onTab
        ? await tabPurchases.update(event.expense, tabId: event.tabId)
        : await updateExpenseUseCase(event.expense);
    switch (result) {
      case ExpenseSuccess():
        RefreshBuses.expenses.notifyChanged();
        if (onTab) RefreshBuses.payLater.notifyChanged();
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            expense: event.expense,
            message: 'Expense updated successfully',
            lastAction: ExpenseAction.updated,
            clearLastDeleted: true,
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.shown("Couldn't save your changes. Try again."),
          ),
        );
    }
  }

  /// Deletes immediately (no confirmation dialog) and remembers the row so
  /// the UI can offer "Undo"; [ExpenseRestore] re-creates it with the same
  /// id, so budgets, reports and the widget stay consistent either way.
  ///
  /// A purchase on a Pay later tab is deleted through [tabPurchases], which
  /// reconciles its tab and returns the link, kept for "Undo". If the tab
  /// can't be read the delete fails rather than skip the reconcile.
  /// [ExpenseDelete.undoable] false (the user already confirmed) keeps
  /// nothing to undo.
  Future<void> _onDelete(
    ExpenseDelete event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.deleting));

    const failed = "Couldn't delete the expense. Try again.";
    final String? tabId;
    try {
      tabId = await tabPurchases.tabIdFor(event.id);
    } catch (e) {
      debugPrint('[error] Reading the Pay later tab of an expense: $e');
      emit(state.copyWith(status: ExpenseBlocStatus.error, message: failed));
      return;
    }

    ExpenseEntity? snapshot;
    final loaded = await getExpenseByIdUseCase(event.id);
    if (loaded case ExpenseSuccess(:final data)) snapshot = data;

    final ExpenseResult<TabLinkSnapshot?> result;
    if (tabId == null) {
      result = switch (await deleteExpenseUseCase(event.id)) {
        ExpenseSuccess() => const ExpenseSuccess(null),
        ExpenseError(:final failure) => ExpenseError(failure),
      };
    } else {
      result = await tabPurchases.delete(event.id);
    }
    switch (result) {
      case ExpenseSuccess(:final data):
        RefreshBuses.expenses.notifyChanged();
        if (tabId != null) RefreshBuses.payLater.notifyChanged();
        final deleted = event.undoable ? snapshot : null;
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            message: 'Expense deleted',
            lastAction: ExpenseAction.deleted,
            lastDeleted: deleted,
            clearLastDeleted: deleted == null,
            lastDeletedLink: data,
            clearLastDeletedLink: data == null,
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.shown(failed),
          ),
        );
    }
  }

  Future<void> _onRestore(
    ExpenseRestore event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.creating));

    final link = event.link;
    final result = link == null
        ? await createExpenseUseCase(event.expense)
        : await tabPurchases.restore(event.expense, link);
    switch (result) {
      case ExpenseSuccess():
        RefreshBuses.expenses.notifyChanged();
        if (link != null) RefreshBuses.payLater.notifyChanged();
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            message: 'Expense restored',
            lastAction: ExpenseAction.restored,
            clearLastDeleted: true,
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.shown("Couldn't restore the expense. Try again."),
          ),
        );
    }
  }

  void _onClearMessage(ExpenseClearMessage event, Emitter<ExpenseState> emit) {
    emit(state.copyWith(status: ExpenseBlocStatus.initial, clearMessage: true));
  }
}
