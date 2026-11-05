import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_surface.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/usecases/get_bill_by_id_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/bloc/expense_bloc.dart';
import 'package:monivo/features/expenses/presentation/pages/expense_details_screen.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_undo.dart';

import '../expense_test_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

void main() {
  late MemoryExpenseRepository expenses;
  late StubBudgetRepository budgets;
  final day = DateTime(2026, 10, 6);
  final dinner = ExpenseEntity(
    id: 'e1',
    budgetId: 'muscat',
    amount: 12.75,
    categoryId: 'food',
    note: 'Dinner',
    date: day,
    time: day.add(const Duration(hours: 20, minutes: 15)),
    tags: const ['friends'],
    createdAt: day,
    updatedAt: day,
  );

  setUp(() async {
    await getIt.reset();
    expenses = MemoryExpenseRepository()..store[dinner.id] = dinner;
    budgets = StubBudgetRepository([
      testBudget(
        id: 'muscat',
        name: 'Muscat',
        currency: 'OMR',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      ),
    ]);
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(
        repository: budgets,
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
    ExpenseUndo.blocFactory = () => memoryExpenseBloc(expenses, budgets);
  });
  tearDown(() async {
    ExpenseUndo.blocFactory = () => getIt<ExpenseBloc>();
    await getIt.reset();
  });

  Future<void> pumpDetails(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = memoryExpenseBloc(expenses, budgets);
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/app/expenses',
      routes: [
        GoRoute(
          path: '/app/expenses',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/details'),
                child: const Text('List'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, _) => BlocProvider<ExpenseBloc>.value(
            value: bloc,
            child: const ExpenseDetailsScreen(expenseId: 'e1'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the expense on one surface, in its budget\'s currency', (
    tester,
  ) async {
    await pumpDetails(tester);

    expect(find.byType(AppSurface), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text(AppMoney.format(12.75, currency: 'OMR')), findsOneWidget);
    expect(find.text('Muscat'), findsOneWidget);
    // The locale's own time format (it puts a narrow space before PM).
    expect(find.text(DateFormat.jm().format(dinner.time)), findsOneWidget);
    expect(find.text('#friends'), findsOneWidget);
  });

  testWidgets('a failed read offers a retry, not "not found"', (tester) async {
    expenses.failReadById = 'database is locked';
    await pumpDetails(tester);

    expect(find.text("Couldn't open this expense"), findsOneWidget);
    expect(find.text('Expense not found'), findsNothing);
    expect(find.textContaining('database is locked'), findsNothing);

    expenses.failReadById = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsWidgets);
  });

  testWidgets('delete asks nothing, closes, and Undo brings it back', (
    tester,
  ) async {
    await pumpDetails(tester);
    await tester.tap(find.byKey(const Key('deleteExpenseButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ExpenseDetailsScreen), findsNothing);
    expect(expenses.store, isEmpty);
    expect(find.byKey(const Key('undoDeleteSnackBar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('undoDeleteAction')));
    await tester.pumpAndSettle();
    expect(expenses.store['e1'], dinner);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits at ${width.toInt()}dp with 200% text', (tester) async {
      await pumpDetails(tester, size: Size(width, 900), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  // UX-059: nothing showed that an expense paid a bill.
  testWidgets('a bill payment names the bill it paid', (tester) async {
    expenses.store['e1'] = dinner.copyWith(billId: 'rent');
    getIt.registerSingleton<GetBillByIdUseCase>(
      GetBillByIdUseCase(
        repository: SafeSpendFakeBillRepository([
          BillEntity(
            id: 'rent',
            title: 'Rent',
            amount: 12.75,
            currency: 'OMR',
            category: BillCategory.rent,
            dueDate: day,
            createdAt: day,
            updatedAt: day,
          ),
        ]),
      ),
    );
    await pumpDetails(tester);

    expect(find.text('Paid bill'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('an expense that paid no bill shows no bill', (tester) async {
    await pumpDetails(tester);
    expect(find.text('Paid bill'), findsNothing);
  });

  // UX-060: the list said "Expense updated" and details "Moved to …",
  // neither with Undo.
  testWidgets('a move says where to, and Undo moves it back', (tester) async {
    budgets.budgets['salalah'] = testBudget(
      id: 'salalah',
      name: 'Salalah',
      currency: 'OMR',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
    );
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('moveExpenseBudgetButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveTarget_salalah')));
    await tester.pumpAndSettle();

    expect(expenses.store['e1']!.budgetId, 'salalah');
    expect(find.text('Moved to Salalah'), findsOneWidget);
    expect(find.text('Salalah'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(expenses.store['e1']!.budgetId, 'muscat');
    expect(find.text('Muscat'), findsOneWidget);
  });

  testWidgets('a moved bill payment offers no Undo: it left its bill', (
    tester,
  ) async {
    expenses.store['e1'] = dinner.copyWith(billId: 'rent');
    budgets.budgets['salalah'] = testBudget(
      id: 'salalah',
      name: 'Salalah',
      currency: 'OMR',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
    );
    await pumpDetails(tester);

    await tester.tap(find.byKey(const Key('moveExpenseBudgetButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveTarget_salalah')));
    await tester.pumpAndSettle();

    expect(find.text('Moved to Salalah'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  // UX-064: the receipt was checked with sync file IO on every build,
  // decoded at full size and unlabelled.
  testWidgets('a receipt is decoded at its display size, and labelled', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('receipt');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/r.jpg')..writeAsBytesSync([0, 1, 2]);
    expenses.store['e1'] = dinner.copyWith(receiptImagePath: file.path);
    await pumpDetails(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.semanticLabel, 'Receipt photo');
    final resized = image.image as ResizeImage;
    expect(resized.width, inInclusiveRange(1, 400));
  });

  testWidgets('a receipt whose file is gone says so', (tester) async {
    expenses.store['e1'] = dinner.copyWith(
      receiptImagePath: '/nonexistent/receipt.jpg',
    );
    await pumpDetails(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Receipt file is missing'), findsOneWidget);
  });

  testWidgets('the details clear the side and bottom insets (UX-063)', (
    tester,
  ) async {
    // The route covers the navigation bar, so the gesture bar and a
    // landscape notch are this screen's to clear.
    tester.view.padding = const FakeViewPadding(left: 44, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pumpDetails(tester);

    final padding =
        tester.widget<ListView>(find.byType(ListView).first).padding!
            as EdgeInsets;
    expect(padding.left, AppSpacing.md + 44);
    expect(padding.bottom, AppSpacing.md + 34);
  });
}
