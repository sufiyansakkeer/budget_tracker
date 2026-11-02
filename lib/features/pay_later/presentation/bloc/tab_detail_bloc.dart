import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/events/refresh_bus.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/usecases/get_categories_usecase.dart';
import '../../domain/entities/pay_later_failure.dart';
import '../../domain/usecases/get_pay_later_analytics_usecase.dart';
import '../../domain/usecases/get_tab_ledger_usecase.dart';
import '../../domain/usecases/manage_tab_usecase.dart';
import '../../domain/usecases/tab_payment_usecase.dart';
import '../pay_later_failure_copy.dart';
import 'tab_detail_event.dart';
import 'tab_detail_state.dart';

/// One tab: its ledger, category breakdown and the actions on it (archive,
/// unarchive, delete, delete a payment). Recording and editing a payment
/// happen in the payment sheet, which uses [payments] directly.
///
/// Reloads whenever a tab, purchase or payment changes
/// ([RefreshBuses.payLater]), an expense changes ([RefreshBuses.expenses],
/// since a purchase is an expense) or the day turns ([RefreshBuses.day]:
/// overdue and settle-up days move with it). After a successful write it
/// notifies [RefreshBuses.payLater] itself.
class TabDetailBloc extends Bloc<TabDetailEvent, TabDetailState> {
  /// Shown when the first load fails for a reason not written for people.
  static const loadFailedMessage =
      "It's still on this device. Try again in a moment.";

  final GetTabLedgerUseCase getLedger;
  final TabPaymentUseCase payments;
  final ManageTabUseCase manageTab;
  final GetPayLaterAnalyticsUseCase getAnalytics;
  final GetCategoriesUseCase getCategories;

  /// "Today" for the screen and its payment sheet.
  final DateTime Function() clock;

  final List<StreamSubscription<void>> _subscriptions = [];
  String? _tabId;

  /// Bumped by every load; a load that finds it moved on drops its result,
  /// so an older, slower read never overwrites a newer one.
  int _loadGeneration = 0;

  TabDetailBloc({
    required this.getLedger,
    required this.payments,
    required this.manageTab,
    required this.getAnalytics,
    required this.getCategories,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       super(const TabDetailState()) {
    on<TabDetailStarted>((event, emit) {
      _tabId = event.tabId;
      return _load(emit, showLoading: true);
    });
    on<TabDetailRefreshed>((event, emit) async {
      if (_tabId != null) await _load(emit, showLoading: false);
    });
    on<TabDetailArchiveRequested>(
      (event, emit) => _write(
        emit,
        (id) => manageTab.archive(id),
        done: 'Tab archived',
        failed: "Couldn't archive the tab. Try again.",
        what: 'Archiving a tab',
      ),
    );
    on<TabDetailUnarchiveRequested>(
      (event, emit) => _write(
        emit,
        (id) => manageTab.unarchive(id),
        done: 'Tab unarchived',
        failed: "Couldn't unarchive the tab. Try again.",
        what: 'Unarchiving a tab',
      ),
    );
    on<TabDetailDeleteRequested>(
      (event, emit) => _write(
        emit,
        (id) => manageTab.delete(id),
        done: 'Tab deleted',
        failed: "Couldn't delete the tab. Try again.",
        what: 'Deleting a tab',
        closes: true,
      ),
    );
    on<TabDetailPaymentDeleteRequested>(
      (event, emit) => _write(
        emit,
        (_) => payments.delete(event.paymentId),
        done: 'Payment deleted',
        failed: "Couldn't delete the payment. Try again.",
        what: 'Deleting a payment',
      ),
    );

    for (final bus in [
      RefreshBuses.payLater,
      RefreshBuses.expenses,
      RefreshBuses.day,
    ]) {
      _subscriptions.add(
        bus.changes.listen((_) {
          if (!isClosed) add(const TabDetailRefreshed());
        }),
      );
    }
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }

  Future<void> _load(
    Emitter<TabDetailState> emit, {
    required bool showLoading,
  }) async {
    final tabId = _tabId!;
    final generation = ++_loadGeneration;
    if (showLoading) {
      emit(
        state.copyWith(
          status: TabDetailStatus.loading,
          clearErrorMessage: true,
        ),
      );
    }
    final categories = await _loadCategories();
    final result = await getLedger(tabId);
    if (generation != _loadGeneration) return;
    switch (result) {
      case PayLaterError(:final failure):
        if (failure.type == PayLaterErrorType.notFound) {
          emit(state.copyWith(status: TabDetailStatus.notFound));
          return;
        }
        debugPrint('[error] Loading a tab: ${failure.message}');
        // A refresh that fails keeps what is on screen; only a screen with
        // nothing to show turns into the error.
        if (showLoading || state.ledger == null) {
          emit(
            state.copyWith(
              status: TabDetailStatus.error,
              errorMessage: failure.shown(loadFailedMessage),
            ),
          );
        }
      case PayLaterSuccess(:final data):
        emit(
          state.copyWith(
            status: TabDetailStatus.loaded,
            ledger: data,
            categories: categories,
            clearErrorMessage: true,
          ),
        );
        if (data.purchases.isEmpty) {
          emit(state.copyWith(byCategory: const {}));
          return;
        }
        final breakdown = await getAnalytics(
          currency: data.tab.currency,
          tabId: tabId,
        );
        if (generation != _loadGeneration) return;
        switch (breakdown) {
          case PayLaterSuccess(:final data):
            emit(state.copyWith(byCategory: data.byExpenseCategory));
          case PayLaterError(:final failure):
            debugPrint('[error] Loading a tab breakdown: ${failure.message}');
            emit(state.copyWith(clearByCategory: true));
        }
    }
  }

  /// Every category by id; what was already loaded when they can't be read
  /// (purchases then fall back to a plain name).
  Future<Map<String, ExpenseCategory>> _loadCategories() async {
    try {
      final result = await getCategories();
      switch (result) {
        case ExpenseSuccess(:final data):
          return {for (final c in data) c.id: c};
        case ExpenseError(:final failure):
          debugPrint(
            '[error] Loading categories for a tab: ${failure.message}',
          );
      }
    } catch (e) {
      debugPrint('[error] Loading categories for a tab: $e');
    }
    return state.categories;
  }

  Future<void> _write(
    Emitter<TabDetailState> emit,
    Future<PayLaterResult<Object?>> Function(String tabId) write, {
    required String done,
    required String failed,
    required String what,
    bool closes = false,
  }) async {
    final tabId = _tabId;
    if (tabId == null || state.busy) return;
    emit(state.copyWith(busy: true));
    final result = await write(tabId);
    switch (result) {
      case PayLaterSuccess():
        RefreshBuses.payLater.notifyChanged();
        emit(
          state.copyWith(
            busy: false,
            message: done,
            messageId: state.messageId + 1,
            deleted: closes,
          ),
        );
      case PayLaterError(:final failure):
        debugPrint('[error] $what: ${failure.message}');
        emit(
          state.copyWith(
            busy: false,
            message: failure.shown(failed),
            messageId: state.messageId + 1,
          ),
        );
    }
  }
}
