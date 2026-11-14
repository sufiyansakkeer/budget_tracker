import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_failure.dart';
import '../../domain/entities/bill_snapshot.dart';
import '../../domain/usecases/create_bill_usecase.dart';
import '../../domain/usecases/delete_bill_usecase.dart';
import '../../domain/usecases/get_bill_by_id_usecase.dart';
import '../../domain/usecases/get_bills_usecase.dart';
import '../../domain/usecases/mark_bill_paid_usecase.dart';
import '../../domain/usecases/mark_bill_unpaid_usecase.dart';
import '../../domain/usecases/pay_bill_usecase.dart';
import '../../domain/usecases/restore_bill_snapshot_usecase.dart';
import '../../domain/usecases/schedule_bill_reminder_usecase.dart';
import '../../domain/usecases/update_bill_usecase.dart';
import '../../../../core/events/refresh_bus.dart';
import 'bill_event.dart';
import 'bill_state.dart';
import '../bill_failure_copy.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  /// Shown when a bill can't be read (not when it no longer exists).
  static const openFailedMessage = "Couldn't open this bill. Try again.";

  final CreateBillUseCase createBillUseCase;
  final UpdateBillUseCase updateBillUseCase;
  final DeleteBillUseCase deleteBillUseCase;
  final GetBillsUseCase getBillsUseCase;
  final GetBillByIdUseCase getBillByIdUseCase;
  final MarkBillPaidUseCase markBillPaidUseCase;
  final MarkBillUnpaidUseCase markBillUnpaidUseCase;
  final PayBillUseCase payBillUseCase;
  final RestoreBillSnapshotUseCase restoreBillSnapshotUseCase;
  final BillReminderService reminderService;

  BillBloc({
    required this.createBillUseCase,
    required this.updateBillUseCase,
    required this.deleteBillUseCase,
    required this.getBillsUseCase,
    required this.getBillByIdUseCase,
    required this.markBillPaidUseCase,
    required this.markBillUnpaidUseCase,
    required this.payBillUseCase,
    required this.restoreBillSnapshotUseCase,
    required this.reminderService,
  }) : super(const BillState()) {
    on<BillLoadAll>(_onLoadAll);
    on<BillLoadById>(_onLoadById);
    on<BillCreate>(_onCreate);
    on<BillUpdate>(_onUpdate);
    on<BillDelete>(_onDelete);
    on<BillMarkPaid>(_onMarkPaid);
    on<BillPayWithExpense>(_onPayWithExpense);
    on<BillMarkUnpaid>(_onMarkUnpaid);
    on<BillUndoRequested>(_onUndo);
    on<BillFilterChanged>(_onFilterChanged);
    on<BillSearchChanged>(_onSearchChanged);
    on<BillRefresh>(_onRefresh);
    on<BillClearMessage>(_onClearMessage);

    // Listen for bill changes from other screens.
    _refreshSubscription = RefreshBuses.bills.changes.listen((_) {
      if (!isClosed) {
        add(const BillRefresh());
      }
    });
  }

  StreamSubscription<void>? _refreshSubscription;

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadAll(BillLoadAll event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.loading));

    final result = await getBillsUseCase();
    switch (result) {
      case BillSuccess(:final data):
        emit(state.copyWith(status: BillBlocStatus.loaded, allBills: data));
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't load your bills. Try again."),
          ),
        );
    }
  }

  Future<void> _onLoadById(BillLoadById event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.loading));

    final result = await getBillByIdUseCase(event.id);
    switch (result) {
      case BillSuccess(:final data):
        emit(state.copyWith(status: BillBlocStatus.loaded, selectedBill: data));
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown(openFailedMessage),
          ),
        );
    }
  }

  Future<void> _onCreate(BillCreate event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.creating));

    final result = await createBillUseCase(event.bill);
    switch (result) {
      case BillSuccess(:final data):
        // Schedule reminder if enabled.
        if (data.reminderEnabled) {
          await reminderService.scheduleReminder(data);
        }
        RefreshBuses.bills.notifyChanged();
        emit(
          state.copyWith(status: BillBlocStatus.success, message: 'Bill added'),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't save the bill. Try again."),
          ),
        );
    }
  }

  Future<void> _onUpdate(BillUpdate event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.updating));

    final result = await updateBillUseCase(event.bill);
    switch (result) {
      case BillSuccess(:final data):
        // Reschedule reminder: cancel old, schedule new if enabled.
        await reminderService.cancelReminder(data);
        if (data.reminderEnabled && !data.isPaid) {
          await reminderService.scheduleReminder(data);
        }
        RefreshBuses.bills.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill updated',
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't save your changes. Try again."),
          ),
        );
    }
  }

  Future<void> _onDelete(BillDelete event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.deleting));

    // Cancel any pending notification for this bill before deleting. The
    // snapshot (bill and payment rows) is what Undo puts back.
    final (before, bill) = await _before(event.id);
    if (bill != null) await reminderService.cancelReminder(bill);

    final result = await deleteBillUseCase(event.id);
    switch (result) {
      case BillSuccess():
        RefreshBuses.bills.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill deleted',
            undo: before == null
                ? null
                : BillUndo(before: before, deleted: true),
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't delete the bill. Try again."),
          ),
        );
    }
  }

  Future<void> _onMarkPaid(BillMarkPaid event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.updating));

    // What Undo puts back: due date, paid state and payment history.
    final (before, previous) = await _before(event.billId);

    final result = await markBillPaidUseCase(event.billId);
    switch (result) {
      case BillSuccess(:final data):
        // As for a payment: the old reminder is cancelled only once the bill
        // is marked paid, and a repeating bill gets the next one.
        if (previous != null) await reminderService.cancelReminder(previous);
        if (data.repeats && data.reminderEnabled) {
          await reminderService.scheduleReminder(data);
        }
        RefreshBuses.bills.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill marked as paid',
            undo: before == null ? null : BillUndo(before: before),
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown(
              "Couldn't mark the bill as paid. Try again.",
            ),
          ),
        );
    }
  }

  Future<void> _onPayWithExpense(
    BillPayWithExpense event,
    Emitter<BillState> emit,
  ) async {
    emit(state.copyWith(status: BillBlocStatus.updating));

    // What Undo puts back; it also deletes the expense recorded below.
    final (before, previous) = await _before(event.billId);

    final result = await payBillUseCase(event.billId);
    switch (result) {
      case BillSuccess(:final data):
        // The old occurrence's reminder is done; a recurring bill gets the
        // next one. Cancelled only once the payment is recorded, so a
        // refused payment keeps its reminder.
        if (previous != null) await reminderService.cancelReminder(previous);
        if (data.bill.repeats && data.bill.reminderEnabled) {
          await reminderService.scheduleReminder(data.bill);
        }
        RefreshBuses.bills.notifyChanged();
        RefreshBuses.expenses.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Marked paid. Expense added to ${data.budget.name}.',
            // The expense is deleted by id, so plain spending (no bill id)
            // goes as surely as a settled set-aside.
            undo: before == null
                ? null
                : BillUndo(before: before, recordedExpenseId: data.expense.id),
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't pay the bill. Try again."),
          ),
        );
    }
  }

  Future<void> _onMarkUnpaid(
    BillMarkUnpaid event,
    Emitter<BillState> emit,
  ) async {
    emit(state.copyWith(status: BillBlocStatus.updating));

    final result = await markBillUnpaidUseCase(event.billId);
    switch (result) {
      case BillSuccess(:final data):
        // Re-schedule reminder if enabled.
        if (data.reminderEnabled) {
          await reminderService.scheduleReminder(data);
        }
        RefreshBuses.bills.notifyChanged();
        // Undoing a payment can delete the expense it recorded.
        RefreshBuses.expenses.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill marked as unpaid',
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown(
              "Couldn't mark the bill as unpaid. Try again.",
            ),
          ),
        );
    }
  }

  Future<void> _onUndo(BillUndoRequested event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.updating));

    final undo = event.undo;
    final result = await restoreBillSnapshotUseCase(
      undo.before,
      recordedExpenseId: undo.recordedExpenseId,
    );
    switch (result) {
      case BillSuccess(:final data):
        // The reminder follows the restored bill: the next occurrence's is
        // replaced by the restored one's, a deleted bill's comes back, and
        // a bill restored as paid has none.
        await reminderService.cancelReminder(data);
        if (data.reminderEnabled && !data.isPaid) {
          await reminderService.scheduleReminder(data);
        }
        RefreshBuses.bills.notifyChanged();
        if (undo.recordedExpenseId != null) {
          RefreshBuses.expenses.notifyChanged();
        }
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: undo.deleted ? 'Bill restored' : 'Payment undone',
            selectedBill: state.selectedBill?.id == data.id ? data : null,
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't undo that. Try again."),
          ),
        );
    }
  }

  /// The bill and its payments as stored before a change, for Undo, and
  /// the bill itself, for its reminder. Without a snapshot the change still
  /// goes ahead, with no Undo.
  Future<(BillSnapshot?, BillEntity?)> _before(String billId) async {
    final result = await restoreBillSnapshotUseCase.capture(billId);
    if (result case BillSuccess(:final data)) return (data, data.bill);
    final bill = await getBillByIdUseCase(billId);
    return (null, bill is BillSuccess<BillEntity> ? bill.data : null);
  }

  void _onFilterChanged(BillFilterChanged event, Emitter<BillState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onSearchChanged(BillSearchChanged event, Emitter<BillState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onRefresh(BillRefresh event, Emitter<BillState> emit) async {
    final result = await getBillsUseCase();
    switch (result) {
      case BillSuccess(:final data):
        // Keep the bill open on a details screen in step with the list, so
        // "mark paid" and edits show up there without leaving the screen.
        final openId = state.selectedBill?.id;
        BillEntity? selected;
        if (openId != null) {
          for (final bill in data) {
            if (bill.id == openId) {
              selected = bill;
              break;
            }
          }
        }
        emit(
          state.copyWith(
            status: BillBlocStatus.loaded,
            allBills: data,
            selectedBill: selected ?? state.selectedBill,
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.shown("Couldn't load your bills. Try again."),
          ),
        );
    }
  }

  void _onClearMessage(BillClearMessage event, Emitter<BillState> emit) {
    emit(state.copyWith(status: BillBlocStatus.initial, clearMessage: true));
  }
}
