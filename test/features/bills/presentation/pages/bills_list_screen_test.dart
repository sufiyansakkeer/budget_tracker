import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_section.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_widgets.dart';
import 'package:monivo/features/bills/presentation/pages/bills_list_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/haptics_recorder.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';

void main() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  BillEntity bill(
    String id,
    double amount,
    int dueIn, {
    String currency = 'INR',
    bool paid = false,
    String? budgetId,
    bool recurring = false,
  }) => BillEntity(
    id: id,
    title: 'Bill $id',
    amount: amount,
    currency: currency,
    category: BillCategory.electricity,
    dueDate: day(dueIn),
    isPaid: paid,
    paidDate: paid ? day(-1) : null,
    budgetId: budgetId,
    isRecurring: recurring,
    recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
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
      ManageBudgetUseCase(
        repository: ListBudgetRepository(),
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
  });
  tearDown(() => getIt.reset());

  late SafeSpendFakeBillRepository repository;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 1400),
    double textScale = 1,
    List<BillEntity>? only,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = SafeSpendFakeBillRepository(only ?? bills);
    final bloc = buildTestBillBloc(repository);
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
    // Each title once as a section (the filter chips repeat them).
    Finder section(String title) => find.descendant(
      of: find.byType(AppSection),
      matching: find.text(title),
    );
    expect(section('Due soon'), findsOneWidget);
    expect(section('Later'), findsOneWidget);
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

  group('UX-100', () {
    String chipLabel(FilterChip chip) => (chip.label as Text).data!;
    List<FilterChip> chips(WidgetTester tester) =>
        tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    Future<void> tapChip(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('filter chips are named like the sections, in sentence case '
        'and in the same order', (tester) async {
      await pump(tester);

      final labels = chips(tester).map(chipLabel).toList();
      expect(labels, [
        'All',
        'Overdue',
        'Due soon',
        'Later',
        'Paid',
        'Recurring',
        'Not linked',
      ]);
      // Every section title on screen is a chip.
      for (final section in ['Overdue', 'Due soon', 'Later', 'Paid']) {
        expect(labels, contains(section));
      }
      expect(find.text('Upcoming'), findsNothing);
      expect(find.text('Due Today'), findsNothing);
    });

    testWidgets('a chip shows exactly its section, with the same summary', (
      tester,
    ) async {
      await pump(tester);

      await tapChip(tester, 'Due soon');
      expect(find.byKey(const ValueKey('bill_netflix')), findsOneWidget);
      expect(find.byType(BillCard), findsOneWidget);
      expect(find.text('1 bill · ₹649'), findsOneWidget);

      await tapChip(tester, 'Later');
      expect(find.byKey(const ValueKey('bill_power')), findsOneWidget);
      expect(find.byType(BillCard), findsOneWidget);
      expect(find.text('1 bill · ₹1,850'), findsOneWidget);
    });

    testWidgets('the selected chip keeps its checkmark', (tester) async {
      await pump(tester);
      for (final chip in chips(tester)) {
        expect(chip.showCheckmark, isTrue, reason: chipLabel(chip));
      }
    });

    testWidgets('a mixed filter keeps paid and unpaid totals apart', (
      tester,
    ) async {
      await pump(tester);

      // None of the bills is linked, so this lists paid and unpaid ones.
      await tapChip(tester, 'Not linked');

      expect(
        find.text(
          '5 bills · ${AppMoney.format(3499, currency: 'INR')} unpaid · '
          '${AppMoney.format(12.5, currency: 'OMR')} unpaid · '
          '${AppMoney.format(300, currency: 'INR')} paid',
        ),
        findsOneWidget,
      );
      // The old subtitle added the paid gym bill to the unpaid ones.
      expect(
        find.textContaining(AppMoney.format(3799, currency: 'INR')),
        findsNothing,
      );
    });

    test('group summary: unpaid groups plain, paid groups count only', () {
      expect(
        BillVisuals.groupSummary([bill('a', 649, 3)]),
        '1 bill · ${AppMoney.format(649, currency: 'INR')}',
      );
      expect(
        BillVisuals.groupSummary([bill('a', 649, -3, paid: true)]),
        '1 bill',
      );
    });

    testWidgets('paying a linked bill has the record-expense icon, a plain '
        'one the check', (tester) async {
      await pump(
        tester,
        only: [
          bill('rent', 1000, 3, budgetId: 'oct'),
          bill('gym', 300, 4),
        ],
      );

      IconData actionIcon(String tooltip) => tester
          .widget<Icon>(
            find.descendant(
              of: find.byTooltip(tooltip),
              matching: find.byType(Icon),
            ),
          )
          .icon!;
      expect(
        actionIcon('Mark paid & record expense'),
        Icons.receipt_long_rounded,
      );
      expect(actionIcon('Mark as paid'), Icons.check_circle_outline_rounded);
      expect(
        BillVisuals.statusIcon(BillStatus.paid),
        isNot(Icons.check_circle_outline_rounded),
      );
    });

    testWidgets('marking a one-time bill paid offers Undo, which puts it '
        'back as it was', (tester) async {
      await pump(tester, only: [bill('gym', 300, 4)]);
      final original = repository.store['gym'];

      await tester.tap(find.byTooltip('Mark as paid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();
      expect(repository.store['gym']!.isPaid, isTrue);
      expect(repository.payments, hasLength(1));

      expect(find.text('Bill marked as paid'), findsOneWidget);
      await tester.tap(find.byKey(const Key('billPaidUndoAction')));
      await tester.pumpAndSettle();

      expect(repository.store['gym'], original);
      expect(repository.payments, isEmpty);
      expect(find.text('Payment undone'), findsOneWidget);
    });

    // UX-111: marking paid from the list gave no haptic, unlike details.
    testWidgets('marking paid from the list confirms with a haptic', (
      tester,
    ) async {
      await pump(tester, only: [bill('gym', 300, 4)]);
      final haptics = recordHaptics(tester);

      await tester.tap(find.byTooltip('Mark as paid'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();
      expect(repository.store['gym']!.isPaid, isTrue);
      expect(haptics, [confirmHaptic]);
    });

    // Failed on the old code: a recurring bill offered no Undo.
    testWidgets('a recurring bill moves to its next date, and Undo moves '
        'it back and removes the payment', (tester) async {
      await pump(tester, only: [bill('gym', 300, 4, recurring: true)]);
      final original = repository.store['gym']!;

      await tester.tap(find.byTooltip('Mark as paid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();
      expect(repository.store['gym']!.dueDate, original.nextDueDate);
      expect(repository.payments, hasLength(1));

      expect(find.text('Bill marked as paid'), findsOneWidget);
      await tester.tap(find.byKey(const Key('billPaidUndoAction')));
      await tester.pumpAndSettle();

      expect(repository.store['gym'], original);
      expect(repository.payments, isEmpty);
      expect(find.text('Payment undone'), findsOneWidget);
    });
  });
}
