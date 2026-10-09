import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_widgets.dart';
import 'package:monivo/features/bills/presentation/pages/bills_list_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

void main() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  BillEntity bill(
    String id,
    double amount,
    int dueIn, {
    String currency = 'INR',
    bool paid = false,
  }) => BillEntity(
    id: id,
    title: 'Bill $id',
    amount: amount,
    currency: currency,
    category: BillCategory.electricity,
    dueDate: day(dueIn),
    isPaid: paid,
    paidDate: paid ? day(-1) : null,
    reminderEnabled: false,
    createdAt: day(-30),
    updatedAt: day(-30),
  );

  final bills = [
    bill('rent', 1000, -3),
    bill('visa', 12.5, -1, currency: 'OMR'),
    bill('netflix', 649, 3),
    bill('power', 1850, 20),
    bill('gym', 300, -10, paid: true),
  ];

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(repository: ListBudgetRepository()),
    );
  });
  tearDown(() => getIt.reset());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 1400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = buildTestBillBloc(SafeSpendFakeBillRepository(bills));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: BlocProvider<BillBloc>.value(
            value: bloc,
            child: const BillsListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups bills as overdue, due soon, later and paid, in that '
      'order', (tester) async {
    await pump(tester);

    final overdue = find.textContaining('2 bills · ₹1,000');
    final soon = find.text('1 bill · ₹649');
    final later = find.text('1 bill · ₹1,850');
    final paid = find.text('1 bill');
    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    for (final f in [overdue, soon, later, paid]) {
      expect(f, findsOneWidget);
    }
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(overdue), lessThan(y(soon)));
    expect(y(soon), lessThan(y(later)));
    expect(y(later), lessThan(y(paid)));
  });

  testWidgets('totals stay per currency (review: OMR was added to rupees '
      'under ₹)', (tester) async {
    await pump(tester);

    expect(
      find.text('2 bills · ₹1,000 · ${AppMoney.format(12.5, currency: 'OMR')}'),
      findsOneWidget,
    );
    expect(find.textContaining('1,012'), findsNothing);
    // The old status tiles and "Next up" card are gone.
    expect(find.text('Next up'), findsNothing);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('rows are compact rows, not cards', (tester) async {
    await pump(tester);
    expect(find.byType(BillCard), findsNWidgets(5));
    expect(find.byType(Card), findsNothing);
  });

  test('due soon covers today and the next six days', () {
    expect(BillVisuals.isDueSoon(bill('a', 1, 0), now), isTrue);
    expect(BillVisuals.isDueSoon(bill('a', 1, 6), now), isTrue);
    expect(BillVisuals.isDueSoon(bill('a', 1, 7), now), isFalse);
    expect(BillVisuals.isDueSoon(bill('a', 1, -1), now), isFalse);
    expect(BillVisuals.isDueSoon(bill('a', 1, 2, paid: true), now), isFalse);
  });

  test('totals add each currency exactly and never across currencies', () {
    final totals = BillVisuals.totalsByCurrency([
      bill('a', 0.1, 1),
      bill('b', 0.2, 1),
      bill('c', 1.005, 1, currency: 'OMR'),
    ]);
    expect(totals, {'INR': 0.3, 'OMR': 1.005});
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      await pump(tester, size: Size(width, 2000), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
