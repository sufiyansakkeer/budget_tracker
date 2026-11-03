import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/events/refresh_bus.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/usecases/get_categories_usecase.dart';
import '../../domain/entities/pay_later_failure.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/usecases/get_tab_ledger_usecase.dart';
import '../../domain/usecases/manage_tab_usecase.dart';
import '../pay_later_failure_copy.dart';
import 'tab_form_state.dart';

/// Loads what the tab form needs and saves the tab.
class TabFormCubit extends Cubit<TabFormState> {
  static const saveFailedMessage = "Couldn't save the tab. Try again.";
  static const loadFailedMessage = "Couldn't open this tab. Try again.";

  final ManageTabUseCase _manageTab;
  final GetTabLedgerUseCase _getLedger;
  final GetCategoriesUseCase _getCategories;
  final ManageBudgetUseCase _manageBudget;

  /// The app currency, used when there is no query and no active budget.
  final String Function() _appCurrency;

  TabFormCubit({
    required ManageTabUseCase manageTab,
    required GetTabLedgerUseCase getLedger,
    required GetCategoriesUseCase getCategories,
    required ManageBudgetUseCase manageBudget,
    required String Function() appCurrency,
  }) : _manageTab = manageTab,
       _getLedger = getLedger,
       _getCategories = getCategories,
       _manageBudget = manageBudget,
       _appCurrency = appCurrency,
       super(const TabFormState());

  /// [tabId] set edits that tab; otherwise a new tab starts in
  /// [currencyQuery], else the active budget's currency, else the app's.
  Future<void> load({String? tabId, String? currencyQuery}) async {
    try {
      var categories = const <ExpenseCategory>[];
      try {
        final result = await _getCategories();
        if (result case ExpenseSuccess(:final data)) categories = data;
      } catch (e) {
        debugPrint('[error] Loading categories for the tab form: $e');
      }

      if (tabId != null) {
        final result = await _getLedger(tabId);
        switch (result) {
          case PayLaterSuccess(:final data):
            emit(
              state.copyWith(
                status: TabFormStatus.ready,
                original: data.tab,
                hasActivity:
                    data.purchases.isNotEmpty || data.payments.isNotEmpty,
                categories: categories,
              ),
            );
          case PayLaterError(:final failure):
            emit(
              state.copyWith(
                status: failure.type == PayLaterErrorType.notFound
                    ? TabFormStatus.notFound
                    : TabFormStatus.loadFailed,
              ),
            );
            if (failure.type != PayLaterErrorType.notFound) {
              debugPrint('[error] Opening a tab: ${failure.message}');
            }
        }
        return;
      }

      var currency = currencyQuery?.trim();
      if (currency == null || currency.isEmpty) {
        try {
          currency = (await _manageBudget.getActive())?.currency;
        } catch (e) {
          debugPrint('[error] Reading the active budget for a new tab: $e');
        }
      }
      emit(
        state.copyWith(
          status: TabFormStatus.ready,
          defaultCurrency: (currency == null || currency.isEmpty)
              ? _appCurrency()
              : currency,
          categories: categories,
        ),
      );
    } catch (e) {
      debugPrint('[error] Loading the tab form: $e');
      emit(state.copyWith(status: TabFormStatus.loadFailed));
    }
  }

  /// Creates or updates [tab] (create when the form has no original).
  Future<void> save(PayLaterTab tab) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true, clearSaveError: true));
    try {
      final result = state.original == null
          ? await _manageTab.create(tab)
          : await _manageTab.update(tab);
      switch (result) {
        case PayLaterSuccess(:final data):
          RefreshBuses.payLater.notifyChanged();
          emit(state.copyWith(saving: false, saved: data));
        case PayLaterError(:final failure):
          emit(
            state.copyWith(
              saving: false,
              saveError: failure.shown(saveFailedMessage),
            ),
          );
      }
    } catch (e) {
      debugPrint('[error] Saving a tab: $e');
      emit(state.copyWith(saving: false, saveError: saveFailedMessage));
    }
  }
}
