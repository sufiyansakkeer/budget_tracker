import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/usecases/create_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/delete_expense_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expense_by_id_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'package:monivo/features/expenses/domain/usecases/update_expense_usecase.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_event.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_state.dart';
import 'package:monivo/features/pay_later/domain/entities/payment_allocation.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';

import '../../../../helpers/pay_later_fakes.dart';
import '../expense_test_fakes.dart';

class _CountingCreate extends CreateExpenseUseCase {
  int calls = 0;
  _CountingCreate(MemoryExpenseRepository repository)
    : super(repository: repository);

  @override
  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) {
    calls++;
    return super.call(expense);
  }
}

class _CountingUpdate extends UpdateExpenseUseCase {
  int calls = 0;
  _CountingUpdate(MemoryExpenseRepository repository)
    : super(repository: repository);

  @override
  Future<ExpenseResult<ExpenseEntity>> call(ExpenseEntity expense) {
    calls++;
    return super.call(expense);
  }
}

class _CountingDelete extends DeleteExpenseUseCase {
  int calls = 0;
  _CountingDelete(MemoryExpenseRepository repository)
    : super(repository: repository);

  @override
  Future<ExpenseResult<void>> call(String id) {
    calls++;
    return super.call(id);
  }
}

ExpenseEntity _expense(String id) => ExpenseEntity(
  id: id,
  budgetId: 'b1',
  amount: 5,
  categoryId: 'food',
  date: DateTime(2026, 11, 1),
  time: DateTime(2026, 11, 1, 12),
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  late MemoryExpenseRepository expenses;
  late FakeTabPurchaseUseCase tabPurchases;
  late _CountingCreate create;
  late _CountingUpdate update;
  late _CountingDelete delete;
  late ExpenseBloc bloc;
  late int expenseNotices;
  late int payLaterNotices;
  late List<StreamSubscription<void>> subscriptions;

  setUp(() {
    expenses = MemoryExpenseRepository();
    tabPurchases = FakeTabPurchaseUseCase();
    create = _CountingCreate(expenses);
    update = _CountingUpdate(expenses);
    delete = _CountingDelete(expenses);
    bloc = ExpenseBloc(
      createExpenseUseCase: create,
      updateExpenseUseCase: update,
      deleteExpenseUseCase: delete,
      getExpenseByIdUseCase: GetExpenseByIdUseCase(repository: expenses),
      getExpensesUseCase: GetExpensesUseCase(repository: expenses),
      getCategoriesUseCase: GetCategoriesUseCase(repository: expenses),
      budgetRepository: StubBudgetRepository(),
      tabPurchases: tabPurchases,
    );
    expenseNotices = 0;
    payLaterNotices = 0;
    subscriptions = [
      RefreshBuses.expenses.changes.listen((_) => expenseNotices++),
      RefreshBuses.payLater.changes.listen((_) => payLaterNotices++),
    ];
  });

  tearDown(() async {
    for (final s in subscriptions) {
      await s.cancel();
    }
    await bloc.close();
  });

  /// Adds [event] and waits for the success or error it ends in.
  Future<ExpenseState> run(ExpenseEvent event) async {
    final done = bloc.stream.firstWhere(
      (s) =>
          s.status == ExpenseBlocStatus.success ||
          s.status == ExpenseBlocStatus.error,
    );
    bloc.add(event);
    final state = await done;
    // Let the broadcast bus deliver its notices.
    await Future<void>.delayed(Duration.zero);
    return state;
  }

  group('"Now" path', () {
    test('ExpenseCreate without tabId never touches pay later', () async {
      final state = await run(ExpenseCreate(_expense('e1')));

      expect(state.status, ExpenseBlocStatus.success);
      expect(tabPurchases.calls, isEmpty);
      expect(create.calls, 1);
      expect(expenses.store.keys, ['e1']);
      expect(expenseNotices, 1);
      expect(payLaterNotices, 0);
    });

    test(
      'ExpenseUpdate without tabId or wasOnTab never touches pay later',
      () async {
        expenses.store['e1'] = _expense('e1');

        final state = await run(
          ExpenseUpdate(_expense('e1').copyWith(amount: 9)),
        );

        expect(state.status, ExpenseBlocStatus.success);
        expect(tabPurchases.calls, isEmpty);
        expect(update.calls, 1);
        expect(payLaterNotices, 0);
      },
    );

    test('deleting a plain expense reads its tab once, then deletes as '
        'before', () async {
      expenses.store['e1'] = _expense('e1');

      final state = await run(const ExpenseDelete('e1'));

      expect(state.status, ExpenseBlocStatus.success);
      expect(tabPurchases.calls, ['tabIdFor:e1']);
      expect(delete.calls, 1);
      expect(state.lastDeleted, _expense('e1'));
      expect(state.lastDeletedLink, isNull);
      expect(payLaterNotices, 0);
    });

    test('restoring without a link re-creates the expense as before', () async {
      final state = await run(ExpenseRestore(_expense('e1')));

      expect(state.status, ExpenseBlocStatus.success);
      expect(state.lastAction, ExpenseAction.restored);
      expect(tabPurchases.calls, isEmpty);
      expect(create.calls, 1);
      expect(payLaterNotices, 0);
    });
  });

  group('tab path', () {
    test('ExpenseCreate with tabId goes through tabPurchases.create', () async {
      final state = await run(ExpenseCreate(_expense('e1'), tabId: 't1'));

      expect(state.status, ExpenseBlocStatus.success);
      expect(state.lastAction, ExpenseAction.created);
      expect(tabPurchases.calls, ['create:e1:t1']);
      expect(create.calls, 0);
      expect(expenseNotices, 1);
      expect(payLaterNotices, 1);
    });

    test(
      'a failed tab create shows its message and notifies nothing',
      () async {
        tabPurchases.failWrites = const ExpenseFailure(
          type: ExpenseErrorType.invalidInput,
          message: 'This tab is in OMR. Pick a budget in OMR.',
        );

        final state = await run(ExpenseCreate(_expense('e1'), tabId: 't1'));

        expect(state.status, ExpenseBlocStatus.error);
        expect(state.message, 'This tab is in OMR. Pick a budget in OMR.');
        expect(expenseNotices, 0);
        expect(payLaterNotices, 0);
      },
    );

    test('ExpenseUpdate with tabId goes through tabPurchases.update', () async {
      final state = await run(ExpenseUpdate(_expense('e1'), tabId: 't2'));

      expect(state.status, ExpenseBlocStatus.success);
      expect(state.lastAction, ExpenseAction.updated);
      expect(tabPurchases.calls, ['update:e1:t2']);
      expect(update.calls, 0);
      expect(payLaterNotices, 1);
    });

    test('turning Pay later off (wasOnTab, no tabId) unlinks through '
        'tabPurchases.update', () async {
      final state = await run(ExpenseUpdate(_expense('e1'), wasOnTab: true));

      expect(state.status, ExpenseBlocStatus.success);
      expect(tabPurchases.calls, ['update:e1:null']);
      expect(update.calls, 0);
      expect(payLaterNotices, 1);
    });

    test('deleting a tab purchase keeps the link for undo', () async {
      expenses.store['e1'] = _expense('e1');
      tabPurchases.tabIds['e1'] = 't1';
      final allocation = PaymentAllocation(
        id: 'a1',
        paymentId: 'p1',
        expenseId: 'e1',
        amount: 2,
        isManual: false,
        createdAt: DateTime(2026, 11, 2),
      );
      tabPurchases.snapshotFor = (_, tabId) =>
          TabLinkSnapshot(tabId: tabId, allocations: [allocation]);

      final state = await run(const ExpenseDelete('e1'));

      expect(state.status, ExpenseBlocStatus.success);
      expect(state.lastAction, ExpenseAction.deleted);
      expect(tabPurchases.calls, ['tabIdFor:e1', 'delete:e1']);
      expect(delete.calls, 0);
      expect(state.lastDeleted, _expense('e1'));
      expect(
        state.lastDeletedLink,
        TabLinkSnapshot(tabId: 't1', allocations: [allocation]),
      );
      expect(expenseNotices, 1);
      expect(payLaterNotices, 1);

      final restored = await run(
        ExpenseRestore(state.lastDeleted!, link: state.lastDeletedLink),
      );
      expect(restored.status, ExpenseBlocStatus.success);
      expect(restored.lastAction, ExpenseAction.restored);
      expect(restored.lastDeleted, isNull);
      expect(restored.lastDeletedLink, isNull);
      expect(tabPurchases.calls.last, 'restore:e1:t1');
      expect(create.calls, 0);
      expect(payLaterNotices, 2);
    });

    test('undoable false clears lastDeleted', () async {
      expenses.store['e1'] = _expense('e1');
      expenses.store['e2'] = _expense('e2');
      tabPurchases.tabIds['e1'] = 't1';

      // A first, undoable delete leaves something to undo ...
      final first = await run(const ExpenseDelete('e2'));
      expect(first.lastDeleted, _expense('e2'));

      // ... which a delete the user confirmed without Undo clears.
      final state = await run(const ExpenseDelete('e1', undoable: false));

      expect(state.status, ExpenseBlocStatus.success);
      expect(state.lastAction, ExpenseAction.deleted);
      expect(state.lastDeleted, isNull);
      expect(state.lastDeletedLink, isNull);
    });

    test('undoable false clears lastDeleted for a plain expense too', () async {
      expenses.store['e1'] = _expense('e1');

      final state = await run(const ExpenseDelete('e1', undoable: false));

      expect(state.status, ExpenseBlocStatus.success);
      expect(state.lastDeleted, isNull);
      expect(delete.calls, 1);
    });

    test('a failed tab lookup is a failed delete, never a plain one', () async {
      expenses.store['e1'] = _expense('e1');
      tabPurchases.tabIdForError = StateError('database is locked');

      final state = await run(const ExpenseDelete('e1'));

      expect(state.status, ExpenseBlocStatus.error);
      expect(state.message, "Couldn't delete the expense. Try again.");
      expect(delete.calls, 0);
      expect(tabPurchases.calls, ['tabIdFor:e1']);
      expect(expenses.store.keys, ['e1']);
      expect(expenseNotices, 0);
    });

    test('a failed tab delete shows the delete error', () async {
      expenses.store['e1'] = _expense('e1');
      tabPurchases.tabIds['e1'] = 't1';
      tabPurchases.failWrites = const ExpenseFailure(
        type: ExpenseErrorType.databaseFailure,
        message: 'Failed to delete expense: locked',
      );

      final state = await run(const ExpenseDelete('e1'));

      expect(state.status, ExpenseBlocStatus.error);
      expect(state.message, "Couldn't delete the expense. Try again.");
      expect(payLaterNotices, 0);
    });
  });
}
