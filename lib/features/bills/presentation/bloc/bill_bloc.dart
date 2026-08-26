import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bill_failure.dart';
import '../../domain/usecases/create_bill_usecase.dart';
import '../../domain/usecases/delete_bill_usecase.dart';
import '../../domain/usecases/get_bill_by_id_usecase.dart';
import '../../domain/usecases/get_bills_usecase.dart';
import '../../domain/usecases/mark_bill_paid_usecase.dart';
import '../../domain/usecases/mark_bill_unpaid_usecase.dart';
import '../../domain/usecases/schedule_bill_reminder_usecase.dart';
import '../../domain/usecases/update_bill_usecase.dart';
import 'bill_event.dart';
import 'bill_refresh_bus.dart';
import 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final CreateBillUseCase createBillUseCase;
  final UpdateBillUseCase updateBillUseCase;
  final DeleteBillUseCase deleteBillUseCase;
  final GetBillsUseCase getBillsUseCase;
  final GetBillByIdUseCase getBillByIdUseCase;
  final MarkBillPaidUseCase markBillPaidUseCase;
  final MarkBillUnpaidUseCase markBillUnpaidUseCase;
  final BillReminderService reminderService;

  BillBloc({
    required this.createBillUseCase,
    required this.updateBillUseCase,
    required this.deleteBillUseCase,
    required this.getBillsUseCase,
    required this.getBillByIdUseCase,
    required this.markBillPaidUseCase,
    required this.markBillUnpaidUseCase,
    required this.reminderService,
  }) : super(const BillState()) {
    on<BillLoadAll>(_onLoadAll);
    on<BillLoadById>(_onLoadById);
    on<BillCreate>(_onCreate);
    on<BillUpdate>(_onUpdate);
    on<BillDelete>(_onDelete);
    on<BillMarkPaid>(_onMarkPaid);
    on<BillMarkUnpaid>(_onMarkUnpaid);
    on<BillFilterChanged>(_onFilterChanged);
    on<BillSearchChanged>(_onSearchChanged);
    on<BillRefresh>(_onRefresh);
    on<BillClearMessage>(_onClearMessage);

    // Listen for bill changes from other screens.
    _refreshSubscription = BillRefreshBus.instance.changes.listen((_) {
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
            message: failure.message,
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
            message: failure.message,
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
        BillRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill added successfully',
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.message,
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
        BillRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill updated successfully',
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  Future<void> _onDelete(BillDelete event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.deleting));

    // Cancel any pending notification for this bill before deleting.
    final bill = await getBillByIdUseCase(event.id);
    if (bill case BillSuccess(:final data)) {
      await reminderService.cancelReminder(data);
    }

    final result = await deleteBillUseCase(event.id);
    switch (result) {
      case BillSuccess():
        BillRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill deleted successfully',
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  Future<void> _onMarkPaid(BillMarkPaid event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: BillBlocStatus.updating));

    // Cancel current reminder.
    final billResult = await getBillByIdUseCase(event.billId);
    if (billResult case BillSuccess(:final data)) {
      await reminderService.cancelReminder(data);
    }

    final result = await markBillPaidUseCase(event.billId);
    switch (result) {
      case BillSuccess(:final data):
        // If recurring, schedule the next reminder.
        if (data.isRecurring && data.reminderEnabled) {
          await reminderService.scheduleReminder(data);
        }
        BillRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: BillBlocStatus.success,
            message: 'Bill marked as paid',
          ),
        );
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.message,
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
        BillRefreshBus.instance.notifyChanged();
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
            message: failure.message,
          ),
        );
    }
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
        emit(state.copyWith(status: BillBlocStatus.loaded, allBills: data));
      case BillError(:final failure):
        emit(
          state.copyWith(
            status: BillBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  void _onClearMessage(BillClearMessage event, Emitter<BillState> emit) {
    emit(state.copyWith(status: BillBlocStatus.initial, clearMessage: true));
  }
}
