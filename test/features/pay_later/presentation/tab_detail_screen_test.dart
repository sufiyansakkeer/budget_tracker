import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_failure.dart';
import 'package:monivo/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_pay_later_analytics_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tab_ledger_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tabs_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/manage_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/tab_payment_usecase.dart';
import 'package:monivo/features/pay_later/presentation/bloc/tab_detail_bloc.dart';
import 'package:monivo/features/pay_later/presentation/pages/tab_detail_screen.dart';

import '../../../helpers/pay_later_fixtures.dart';
import '../../../helpers/pay_later_memory_repository.dart';

class _FakeCategories implements GetCategoriesUseCase {
  @override
  Future<ExpenseResult<List<ExpenseCategory>>> call() async =>
      const ExpenseSuccess([
        ExpenseCategory(
          id: 'cat',
          name: 'Meals',
          icon: 'restaurant',
          colorHex: '#FF0000',
        ),
        ExpenseCategory(
          id: 'drinks',
          name: 'Drinks',
          icon: 'local_cafe',
          colorHex: '#00FF00',
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ExpenseEntity purchase(
  String id,
  double amount,
  DateTime date, {
  String? note,
  String categoryId = 'cat',
}) => payLaterExpense(id, amount: amount).copyWith(
  date: date,
  time: DateTime(date.year, date.month, date.day, 12),
  note: note,
  categoryId: categoryId,
);

TabPayment payment(String id, double amount, DateTime paidDate) => TabPayment(
  id: id,
  tabId: 't1',
  amount: amount,
  paidDate: paidDate,
  createdAt: paidDate,
  updatedAt: paidDate,
);

String omr(double amount) => AppMoney.format(amount, currency: 'OMR');

void main() {
  /// 2 Nov 2026, 10:00.
  final now = DateTime(2026, 11, 2, 10);
  DateTime clock() => now;

  late MemoryPayLaterRepository repo;

  setUp(() => repo = MemoryPayLaterRepository());

  /// Allocations as a reconciled database holds them.
  Future<void> reconcile() => ReconcileTabUseCase(repository: repo)('t1');

  Future<TabDetailBloc> pump(WidgetTester tester, {String tabId = 't1'}) async {
    final getLedger = GetTabLedgerUseCase(repository: repo, clock: clock);
    final bloc = TabDetailBloc(
      getLedger: getLedger,
      payments: TabPaymentUseCase(
        repository: repo,
        reconcileTab: ReconcileTabUseCase(repository: repo),
        clock: clock,
      ),
      manageTab: ManageTabUseCase(repository: repo, clock: clock),
      getAnalytics: GetPayLaterAnalyticsUseCase(
        getTabs: GetTabsUseCase(repository: repo),
        getLedger: getLedger,
        clock: clock,
      ),
      getCategories: _FakeCategories(),
      clock: clock,
    );
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: AppRouter.payLaterPath,
      routes: [
        GoRoute(
          path: AppRouter.payLaterPath,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                const Text('Overview'),
                TextButton(
                  onPressed: () =>
                      context.push('${AppRouter.payLaterPath}/$tabId'),
                  child: const Text('Open tab'),
                ),
              ],
            ),
          ),
          routes: [
            GoRoute(
              path: ':id/edit',
              builder: (_, state) => Scaffold(
                body: Text('Edit tab ${state.pathParameters['id']}'),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => BlocProvider.value(
                value: bloc,
                child: TabDetailScreen(tabId: state.pathParameters['id']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/app/expenses/add',
          builder: (_, state) => Scaffold(
            body: Text('Add expense ${state.uri.queryParameters['tab']}'),
          ),
        ),
        GoRoute(
          path: '/app/expenses/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Expense ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open tab'));
    await tester.pumpAndSettle();
    return bloc;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('tabMoreMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Finder header() => find.byKey(const Key('tabHeader'));
  Finder balance() => find.byKey(const Key('tabBalance'));
  Finder purchaseRow(String id) => find.byKey(Key('tabPurchase_$id'));
  Finder paymentTile(String id) => find.byKey(Key('tabPayment_$id'));

  testWidgets('settle all records owed and shows Paid', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1.5, DateTime(2026, 10, 30)))
      ..addPurchase('t1', purchase('e2', 2, DateTime(2026, 11, 1)));

    await pump(tester);

    expect(
      find.descendant(of: balance(), matching: find.text(omr(3.5))),
      findsOneWidget,
    );
    for (final id in ['e1', 'e2']) {
      expect(
        find.descendant(of: purchaseRow(id), matching: find.text('Unpaid')),
        findsOneWidget,
      );
    }

    await tapVisible(tester, find.byKey(const Key('tabSettleAllButton')));
    final amount = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('paymentAmountField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(amount.controller.text, '3.5');
    await tapVisible(tester, find.byKey(const Key('paymentSaveButton')));

    expect(repo.payments.values.single.amount, 3.5);
    expect(find.text('Tab settled'), findsOneWidget);
    for (final id in ['e1', 'e2']) {
      await tester.ensureVisible(purchaseRow(id));
      expect(
        find.descendant(of: purchaseRow(id), matching: find.text('Paid')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: balance(), matching: find.text('Settled')),
      findsOneWidget,
    );
    // Nothing owed: nothing to settle.
    expect(find.byKey(const Key('tabSettleAllButton')), findsNothing);
  });

  testWidgets('deleting a payment asks and names the amount owed again', (
    tester,
  ) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)))
      ..addPurchase('t1', purchase('e2', 1, DateTime(2026, 10, 25)));
    repo.payments['p1'] = payment('p1', 1.5, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);
    expect(
      find.descendant(of: balance(), matching: find.text(omr(1.5))),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('Payments'));
    await tester.ensureVisible(paymentTile('p1'));
    await tester.pumpAndSettle();
    await tester.longPress(paymentTile('p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete payment'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this payment?'), findsOneWidget);
    expect(
      find.text('${omr(1.5)} will be owed again on Cafeteria.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.payments, isEmpty);
    expect(find.text('Payment deleted'), findsOneWidget);
    expect(
      find.descendant(of: balance(), matching: find.text(omr(3))),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the payment delete keeps it', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)));
    repo.payments['p1'] = payment('p1', 1, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);
    await tapVisible(tester, find.text('Payments'));
    await tester.longPress(paymentTile('p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.payments.keys, ['p1']);
  });

  testWidgets('archive refused while owing explains why', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)));

    await pump(tester);
    await openMenu(tester, 'Archive');

    expect(find.text("Can't archive yet"), findsOneWidget);
    expect(
      find.text(
        'Cafeteria still owes ${omr(2)}. Settle it first, then archive it.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.tabs['t1']!.isArchived, isFalse);
  });

  testWidgets('archive refused while in credit explains why', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1, DateTime(2026, 10, 20)));
    repo.payments['p1'] = payment('p1', 1.5, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);
    await openMenu(tester, 'Archive');

    expect(
      find.text(
        'Cafeteria holds ${omr(0.5)} in credit. Add a purchase to use it, '
        'or lower the payment that left it, then archive the tab.',
      ),
      findsOneWidget,
    );
    expect(repo.tabs['t1']!.isArchived, isFalse);
  });

  testWidgets('a settled tab archives, then hides add to tab and unarchives', (
    tester,
  ) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1, DateTime(2026, 10, 20)));
    repo.payments['p1'] = payment('p1', 1, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);
    expect(find.byKey(const Key('tabAddButton')), findsOneWidget);
    await openMenu(tester, 'Archive');

    expect(repo.tabs['t1']!.isArchived, isTrue);
    expect(find.text('Tab archived'), findsOneWidget);
    expect(find.byKey(const Key('tabAddButton')), findsNothing);

    await openMenu(tester, 'Unarchive');
    expect(repo.tabs['t1']!.isArchived, isFalse);
    expect(find.byKey(const Key('tabAddButton')), findsOneWidget);
  });

  testWidgets('add to tab opens the expense form on this tab', (tester) async {
    repo.addTab(payLaterTab('t1'));

    await pump(tester);
    await tapVisible(tester, find.byKey(const Key('tabAddButton')));

    expect(find.text('Add expense t1'), findsOneWidget);
  });

  testWidgets('edit opens the tab form', (tester) async {
    repo.addTab(payLaterTab('t1'));

    await pump(tester);
    await tester.tap(find.byTooltip('Edit tab'));
    await tester.pumpAndSettle();

    expect(find.text('Edit tab t1'), findsOneWidget);
  });

  testWidgets('tapping a purchase opens the expense', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)));

    await pump(tester);
    await tapVisible(tester, purchaseRow('e1'));

    expect(find.text('Expense e1'), findsOneWidget);
  });

  testWidgets('header shows in credit, overdue and next settle-up', (
    tester,
  ) async {
    final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 1));
    repo
      ..addTab(payLaterTab('t1', rhythm: weekly))
      // 1–7 Oct, settled up 8 Oct: overdue.
      ..addPurchase('t1', purchase('old', 3, DateTime(2026, 10, 2)))
      // 29 Oct – 4 Nov, settles up 5 Nov.
      ..addPurchase('t1', purchase('new', 1.25, DateTime(2026, 11, 1)));

    await pump(tester);

    expect(
      find.descendant(of: header(), matching: find.text('${omr(3)} overdue')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header(), matching: find.text('Settle up 5 Nov')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: balance(), matching: find.text(omr(4.25))),
      findsOneWidget,
    );
    // Total added and paid.
    expect(
      find.descendant(of: header(), matching: find.text('Total added')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header(), matching: find.text('Total paid')),
      findsOneWidget,
    );
  });

  testWidgets('a settle-up day that is today says today', (tester) async {
    // Periods start on the 2nd of each week from 26 Oct: 2 Nov is a
    // settle-up day.
    final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 26));
    repo
      ..addTab(payLaterTab('t1', rhythm: weekly))
      ..addPurchase('t1', purchase('a', 1, DateTime(2026, 10, 27)));

    await pump(tester);

    expect(
      find.descendant(of: header(), matching: find.text('Settle up today')),
      findsOneWidget,
    );
  });

  testWidgets('a settle-up day that is tomorrow says tomorrow', (tester) async {
    final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 27));
    repo
      ..addTab(payLaterTab('t1', rhythm: weekly))
      ..addPurchase('t1', purchase('a', 1, DateTime(2026, 11, 1)));

    await pump(tester);

    expect(
      find.descendant(of: header(), matching: find.text('Settle up tomorrow')),
      findsOneWidget,
    );
  });

  testWidgets('a tab in credit or settled shows no settle-up day (QA F4)', (
    tester,
  ) async {
    final weekly = EveryDays(days: 7, anchor: DateTime(2026, 10, 26));
    repo
      ..addTab(payLaterTab('t1', rhythm: weekly))
      ..addPurchase('t1', purchase('a', 1, DateTime(2026, 10, 27)));
    repo.payments['p1'] = payment('p1', 1.5, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);

    expect(
      find.descendant(of: header(), matching: find.textContaining('Settle up')),
      findsNothing,
    );
  });

  testWidgets('a payment that leaves credit says in credit after (T12)', (
    tester,
  ) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1, DateTime(2026, 10, 20)));
    repo.payments['p1'] = payment('p1', 1.5, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);
    await tapVisible(tester, find.text('Payments'));

    expect(
      find.descendant(
        of: paymentTile('p1'),
        matching: find.text('In credit after: ${omr(0.5)}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a tab in credit says so', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1, DateTime(2026, 10, 20)));
    repo.payments['p1'] = payment('p1', 1.5, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);

    expect(
      find.descendant(of: balance(), matching: find.text('In credit')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: balance(), matching: find.text(omr(0.5))),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tabRecordPaymentButton')), findsNothing);
  });

  testWidgets('a passed manual date asks for the next one; earlier is named', (
    tester,
  ) async {
    repo
      ..addTab(
        payLaterTab(
          't1',
          rhythm: ManualDate(
            nextSettleDate: DateTime(2026, 10, 20),
            anchor: DateTime(2026, 10, 1),
          ),
        ),
      )
      // Before the anchor: the "earlier" period.
      ..addPurchase('t1', purchase('e0', 1, DateTime(2026, 9, 25)))
      // 1–19 Oct, settled up 20 Oct.
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 10)))
      // After the passed date: open, no settle-up day.
      ..addPurchase('t1', purchase('e2', 3, DateTime(2026, 10, 25)));

    await pump(tester);

    expect(find.text('Set your next settle-up date'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    await tester.ensureVisible(find.text('No settle-up date yet'));
    expect(find.text('No settle-up date yet'), findsOneWidget);

    await tapVisible(tester, find.text('Set date'));
    expect(find.text('Edit tab t1'), findsOneWidget);
  });

  testWidgets('a new pick-a-date tab does not file today under Earlier', (
    tester,
  ) async {
    // No anchor yet: the current period has no first day.
    repo
      ..addTab(
        payLaterTab(
          't1',
          rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 20)),
        ),
      )
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 11, 2)));

    await pump(tester);

    expect(find.text('Earlier'), findsNothing);
    expect(find.text('Until 19 Nov'), findsOneWidget);
    expect(find.text('Settle up 20 Nov'), findsWidgets);
  });

  testWidgets('a pick-a-date tab with no date yet is not scheduled', (
    tester,
  ) async {
    repo
      ..addTab(payLaterTab('t1', rhythm: const ManualDate()))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 11, 2)));

    await pump(tester);

    expect(find.text('Earlier'), findsNothing);
    expect(find.text('Not scheduled yet'), findsOneWidget);
    expect(find.text('No settle-up date yet'), findsOneWidget);
  });

  testWidgets('payments show what they covered and the balance after', (
    tester,
  ) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase(
        't1',
        purchase('e1', 2, DateTime(2026, 10, 20), note: 'Lunch'),
      )
      ..addPurchase(
        't1',
        purchase('e2', 1, DateTime(2026, 10, 25), note: 'Coffee'),
      );
    final payments = TabPaymentUseCase(
      repository: repo,
      reconcileTab: ReconcileTabUseCase(repository: repo),
      clock: clock,
    );
    // Chosen: the coffee first, then the rest FIFO.
    await payments.record(
      paymentId: 'p1',
      tabId: 't1',
      amount: 1.5,
      paidDate: DateTime(2026, 10, 28),
      chosenExpenseIds: {'e2'},
    );
    await payments.record(
      paymentId: 'p2',
      tabId: 't1',
      amount: 1.5,
      paidDate: DateTime(2026, 10, 30),
    );

    await pump(tester);
    await tapVisible(tester, find.text('Payments'));

    final first = paymentTile('p1');
    expect(
      find.descendant(of: first, matching: find.textContaining('Coffee')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.text('You chose these')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: first,
        matching: find.text('Owed after: ${omr(1.5)}'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(paymentTile('p2'));
    expect(
      find.descendant(of: paymentTile('p2'), matching: find.text('Settled')),
      findsOneWidget,
    );
  });

  testWidgets('a payment is edited from its tile', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)));
    repo.payments['p1'] = payment('p1', 1, DateTime(2026, 10, 28));
    await reconcile();

    await pump(tester);
    await tapVisible(tester, find.text('Payments'));
    await tester.longPress(paymentTile('p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit payment'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('paymentAmountField')), '1.25');
    await tester.pump();
    await tapVisible(tester, find.byKey(const Key('paymentSaveButton')));

    expect(repo.payments['p1']!.amount, 1.25);
    expect(find.text('Payment updated'), findsOneWidget);
    expect(
      find.descendant(of: balance(), matching: find.text(omr(0.75))),
      findsOneWidget,
    );
  });

  testWidgets('category breakdown sums purchases by expense category', (
    tester,
  ) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)))
      ..addPurchase('t1', purchase('e2', 1, DateTime(2026, 10, 21)))
      ..addPurchase(
        't1',
        purchase('e3', 0.5, DateTime(2026, 10, 22), categoryId: 'drinks'),
      );

    await pump(tester);
    final breakdown = find.byKey(const Key('tabCategoryBreakdown'));
    await tester.scrollUntilVisible(
      breakdown,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: breakdown, matching: find.text('Meals')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breakdown, matching: find.text(omr(3))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breakdown, matching: find.text('Drinks')),
      findsOneWidget,
    );
  });

  testWidgets('an unused tab can be deleted after confirming', (tester) async {
    repo.addTab(payLaterTab('t1'));

    await pump(tester);
    await openMenu(tester, 'Delete tab');
    expect(find.text('Delete this tab?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.tabs, isEmpty);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Tab deleted'), findsOneWidget);
  });

  testWidgets('a used tab offers no delete', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 1, DateTime(2026, 10, 20)));

    await pump(tester);
    await tester.tap(find.byKey(const Key('tabMoreMenu')));
    await tester.pumpAndSettle();

    expect(find.text('Delete tab'), findsNothing);
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('a failed load shows the error with try again', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..readError = StateError('disk I/O');

    await pump(tester);

    expect(find.text("Couldn't open this tab."), findsOneWidget);
    expect(find.textContaining('disk I/O'), findsNothing);
    expect(find.textContaining('Failed to'), findsNothing);

    repo.readError = null;
    await tapVisible(tester, find.text('Try again'));
    expect(header(), findsOneWidget);
  });

  testWidgets('a missing tab says so', (tester) async {
    await pump(tester, tabId: 'gone');

    expect(find.text('Tab not found'), findsOneWidget);
  });

  testWidgets('another screen changing the tab reloads it', (tester) async {
    repo
      ..addTab(payLaterTab('t1'))
      ..addPurchase('t1', purchase('e1', 2, DateTime(2026, 10, 20)));

    await pump(tester);
    repo.addPurchase('t1', purchase('e2', 1, DateTime(2026, 10, 21)));
    RefreshBuses.expenses.notifyChanged();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: balance(), matching: find.text(omr(3))),
      findsOneWidget,
    );
  });
}
