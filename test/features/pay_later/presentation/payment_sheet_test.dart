import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_ledger.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_payment_usecase.dart';
import 'package:monivo/features/pay_later/presentation/widgets/payment_sheet.dart';

import '../../../helpers/pay_later_fixtures.dart';
import '../../../helpers/pay_later_memory_repository.dart';

/// The real use case over memory, recording every record call and able to
/// hold one open (a slow write) or fail the next one (a timeout).
class _RecordingPayments extends TabPaymentUseCase {
  _RecordingPayments(MemoryPayLaterRepository repo, DateTime Function() clock)
    : super(
        repository: repo,
        reconcileTab: ReconcileTabUseCase(repository: repo),
        clock: clock,
      );

  final List<String> recordedIds = [];
  final List<Set<String>> chosen = [];
  final List<TabPayment> updated = [];
  Completer<void>? gate;
  PayLaterFailure? failNext;

  @override
  Future<PayLaterResult<TabPayment>> record({
    required String paymentId,
    required String tabId,
    required double amount,
    required DateTime paidDate,
    String? note,
    Set<String> chosenExpenseIds = const {},
  }) async {
    recordedIds.add(paymentId);
    chosen.add(chosenExpenseIds);
    final wait = gate;
    if (wait != null) await wait.future;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return PayLaterError(failure);
    }
    return super.record(
      paymentId: paymentId,
      tabId: tabId,
      amount: amount,
      paidDate: paidDate,
      note: note,
      chosenExpenseIds: chosenExpenseIds,
    );
  }

  @override
  Future<PayLaterResult<TabPayment>> update(TabPayment payment) {
    updated.add(payment);
    return super.update(payment);
  }
}

ExpenseEntity purchase(String id, double amount, DateTime date) =>
    payLaterExpense(id, amount: amount).copyWith(
      date: date,
      time: DateTime(date.year, date.month, date.day, 12),
      note: 'Meal $id',
    );

String omr(double amount) => AppMoney.format(amount, currency: 'OMR');

void main() {
  /// 2 Nov 2026, 10:00.
  final now = DateTime(2026, 11, 2, 10);
  DateTime clock() => now;

  late MemoryPayLaterRepository repo;
  late _RecordingPayments payments;

  setUp(() {
    repo = MemoryPayLaterRepository()
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1, DateTime(2026, 10, 20)))
      ..addPurchase('t1', purchase('e2', 2.5, DateTime(2026, 10, 25)))
      ..addPurchase('t1', purchase('e3', 0.75, DateTime(2026, 10, 30)));
    payments = _RecordingPayments(repo, clock);
  });

  Future<TabLedger> ledger() async {
    final result = await GetTabLedgerUseCase(repository: repo, clock: clock)(
      't1',
    );
    return (result as PayLaterSuccess<TabLedger>).data;
  }

  /// Opens the sheet over a page; the sheet's result lands in [results].
  Future<List<String?>> open(
    WidgetTester tester, {
    bool settleAll = false,
    PaymentLine? editing,
  }) async {
    final current = await ledger();
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await PaymentSheet.show(
                  context,
                  ledger: current,
                  payments: payments,
                  settleAll: settleAll,
                  editing: editing,
                  clock: clock,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return results;
  }

  String amountText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('paymentAmountField')),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  Future<void> enterAmount(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('paymentAmountField')), text);
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const Key('paymentSaveButton'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save, warnIfMissed: false);
  }

  Finder owedAfter() => find.byKey(const Key('paymentOwedAfter'));

  String owedAfterText(WidgetTester tester) =>
      tester.widget<Text>(owedAfter()).data!;

  testWidgets('choosing purchases prefills their total', (tester) async {
    await open(tester);
    expect(amountText(tester), '');

    await tester.tap(find.text('Choose what this pays'));
    await tester.pumpAndSettle();
    // Listed oldest first, each with what it still owes.
    final rows = [
      for (final id in ['e1', 'e2', 'e3'])
        tester.getTopLeft(find.byKey(Key('paymentChoose_$id'))).dy,
    ];
    expect(rows, orderedEquals([...rows]..sort()));

    for (final id in ['e1', 'e3']) {
      final row = find.byKey(Key('paymentChoose_$id'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pump();
    }

    expect(amountText(tester), '1.75');
    expect(owedAfterText(tester), 'Owed after: ${omr(2.5)}');

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(payments.chosen.single, {'e1', 'e3'});
    final allocations = repo.allocations.values.toList();
    expect({for (final a in allocations) a.expenseId}, {'e1', 'e3'});
    expect(allocations.every((a) => a.isManual), isTrue);
  });

  testWidgets('a purchase already paid is not offered', (tester) async {
    repo.payments['p0'] = TabPayment(
      id: 'p0',
      tabId: 't1',
      amount: 1,
      paidDate: DateTime(2026, 10, 21),
      createdAt: DateTime(2026, 10, 21),
      updatedAt: DateTime(2026, 10, 21),
    );
    await ReconcileTabUseCase(repository: repo)('t1');

    await open(tester);
    await tester.tap(find.text('Choose what this pays'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paymentChoose_e1')), findsNothing);
    expect(find.byKey(const Key('paymentChoose_e2')), findsOneWidget);
  });

  testWidgets('payment sheet saves once on double tap', (tester) async {
    final results = await open(tester, settleAll: true);
    payments.gate = Completer<void>();

    await tapSave(tester);
    await tester.pump();
    // Still saving: the second tap must not send another payment.
    await tester.tap(
      find.byKey(const Key('paymentSaveButton')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(payments.recordedIds, hasLength(1));
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('paymentSaveButton')),
    );
    expect(save.onPressed, isNull);

    payments.gate!.complete();
    await tester.pumpAndSettle();

    expect(payments.recordedIds, hasLength(1));
    expect(repo.createdPaymentIds, hasLength(1));
    expect(repo.payments.values.single.amount, 4.25);
    expect(results, ['Tab settled']);
  });

  testWidgets('a retry after a failure sends the same payment id', (
    tester,
  ) async {
    await open(tester, settleAll: true);
    payments.failNext = const PayLaterFailure(
      type: PayLaterErrorType.databaseFailure,
      message: 'Failed to record payment: database is locked',
    );

    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't record the payment. Try again."),
      findsOneWidget,
    );
    expect(find.textContaining('database is locked'), findsNothing);

    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(payments.recordedIds, hasLength(2));
    expect(payments.recordedIds.toSet(), hasLength(1));
    expect(repo.createdPaymentIds, hasLength(1));
  });

  testWidgets('overpay shows the limit', (tester) async {
    await open(tester);

    await enterAmount(tester, '5');

    expect(find.text('You owe ${omr(4.25)} on this tab.'), findsOneWidget);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(payments.recordedIds, isEmpty);
    expect(repo.payments, isEmpty);
  });

  testWidgets('settle all prefills what is owed; owed after follows', (
    tester,
  ) async {
    await open(tester, settleAll: true);

    expect(amountText(tester), '4.25');
    expect(owedAfterText(tester), 'Owed after: ${omr(0)}');

    await enterAmount(tester, '1.5');
    expect(owedAfterText(tester), 'Owed after: ${omr(2.75)}');
  });

  testWidgets('an empty or zero amount is refused before saving', (
    tester,
  ) async {
    await open(tester);

    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);

    await enterAmount(tester, '0');
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect(payments.recordedIds, isEmpty);
  });

  testWidgets('a saved payment tells the tab screens to reload', (
    tester,
  ) async {
    var notified = 0;
    final subscription = RefreshBuses.payLater.changes.listen(
      (_) => notified++,
    );
    addTearDown(subscription.cancel);
    final results = await open(tester);

    await enterAmount(tester, '1');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(notified, 1);
    expect(results, ['Payment recorded']);
    final saved = repo.payments.values.single;
    expect(saved.paidDate, DateTime(2026, 11, 2));
  });

  /// A payment of 5.000 on 4.250 of purchases: it holds 0.750 credit and
  /// the tab owes nothing.
  Future<PaymentLine> creditPayment() async {
    repo.payments['p1'] = TabPayment(
      id: 'p1',
      tabId: 't1',
      amount: 5,
      paidDate: DateTime(2026, 10, 28),
      note: 'Cash',
      createdAt: DateTime(2026, 10, 28),
      updatedAt: DateTime(2026, 10, 28),
    );
    await ReconcileTabUseCase(repository: repo)('t1');
    final current = await ledger();
    expect(current.owed, 0);
    expect(current.credit, 0.75);
    return current.payments.single;
  }

  testWidgets('a payment holding credit saves a note-only edit', (
    tester,
  ) async {
    final results = await open(tester, editing: await creditPayment());

    // Not raised: no limit applies.
    expect(find.textContaining('can be up to'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('paymentNoteField')),
      'Cash at the counter',
    );
    await tester.pump();
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(payments.updated.single.amount, 5);
    expect(repo.payments['p1']!.note, 'Cash at the counter');
    expect(repo.payments['p1']!.amount, 5);
    expect(results, ['Payment updated']);
  });

  testWidgets('a payment holding credit saves a date-only edit', (
    tester,
  ) async {
    final results = await open(tester, editing: await creditPayment());

    await tester.tap(find.byKey(const Key('paymentDateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('27'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repo.payments['p1']!.paidDate, DateTime(2026, 10, 27));
    expect(repo.payments['p1']!.amount, 5);
    expect(results, ['Payment updated']);
  });

  testWidgets('a payment holding credit still cannot be raised past owed', (
    tester,
  ) async {
    await open(tester, editing: await creditPayment());

    // Owes nothing; this payment covers 4.250 of purchases.
    await enterAmount(tester, '5.5');

    expect(
      find.text('This payment can be up to ${omr(4.25)}.'),
      findsOneWidget,
    );
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(payments.updated, isEmpty);
  });

  testWidgets('editing a payment checks it against its own limit', (
    tester,
  ) async {
    await payments.record(
      paymentId: 'p1',
      tabId: 't1',
      amount: 1,
      paidDate: DateTime(2026, 10, 28),
      note: 'Cash',
    );
    final line = (await ledger()).payments.single;
    final results = await open(tester, editing: line);

    expect(amountText(tester), '1');
    expect(find.text('Choose what this pays'), findsNothing);

    // Owed 3.250 + this payment's 1.000.
    await enterAmount(tester, '5');
    expect(
      find.text('This payment can be up to ${omr(4.25)}.'),
      findsOneWidget,
    );

    await enterAmount(tester, '2');
    expect(owedAfterText(tester), 'Owed after: ${omr(2.25)}');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(payments.updated.single.id, 'p1');
    expect(payments.updated.single.note, 'Cash');
    expect(repo.payments['p1']!.amount, 2);
    expect(results, ['Payment updated']);
  });
}
