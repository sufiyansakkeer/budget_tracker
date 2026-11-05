import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/primary_button.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bill_form_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

BillEntity rent({required DateTime dueDate}) => BillEntity(
  id: 'rent',
  title: 'Rent',
  amount: 100,
  currency: 'INR',
  category: BillCategory.rent,
  dueDate: dueDate,
  reminderEnabled: true,
  reminderOffsetDays: 1,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

void main() {
  late SafeSpendFakeBillRepository bills;
  late BillBloc bloc;
  late GoRouter router;

  setUp(() async {
    await getIt.reset();
    bills = SafeSpendFakeBillRepository();
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  /// The form pushed over the bills list, as the app opens it.
  Future<void> pumpForm(WidgetTester tester, {String? billId}) async {
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(
        repository: ListBudgetRepository(const []),
        reconcileTabs: FakeReconcileTabUseCase(),
      ),
    );
    bloc = buildTestBillBloc(bills);
    router = GoRouter(
      initialLocation: '/app/bills',
      routes: [
        GoRoute(
          path: '/app/bills',
          builder: (_, _) => const Scaffold(body: Text('Bills list')),
        ),
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: BillFormScreen(billId: billId),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    router.push('/form');
    await tester.pumpAndSettle();
  }

  Finder saveButton(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(PrimaryButton));

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextField, label), text);
    await tester.pump();
  }

  Future<void> openMoreOptions(WidgetTester tester) async {
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
  }

  testWidgets('the save button stays above an open keyboard', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await pumpForm(tester);

    final save = tester.getRect(saveButton('Add bill'));
    expect(save.bottom, lessThanOrEqualTo(800 - 300));
  });

  group('closing', () {
    testWidgets('an untouched new bill closes at once', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BillFormScreen), findsNothing);
      expect(find.text('Bills list'), findsOneWidget);
    });

    testWidgets('closing with something entered asks first', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Bill name', 'Rent');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this bill?'), findsOneWidget);
      expect(find.text("What you entered hasn't been saved."), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(BillFormScreen), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(BillFormScreen), findsNothing);
      expect(bills.store, isEmpty);
    });

    testWidgets('the back gesture asks too', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Amount', '250');

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(find.text('Discard this bill?'), findsOneWidget);
    });

    testWidgets('an unchanged edit closes quietly; a changed one asks', (
      tester,
    ) async {
      bills.store['rent'] = rent(dueDate: DateTime(2099, 1, 5));
      await pumpForm(tester, billId: 'rent');
      expect(find.widgetWithText(TextField, 'Rent'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BillFormScreen), findsNothing);

      router.push('/form');
      await tester.pumpAndSettle();
      await enter(tester, 'Amount', '150');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text("Your changes haven't been saved."), findsOneWidget);
    });

    testWidgets('saving closes without asking', (tester) async {
      await pumpForm(tester);
      await enter(tester, 'Bill name', 'Rent');
      await enter(tester, 'Amount', '250');

      await tester.tap(saveButton('Add bill'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this bill?'), findsNothing);
      expect(find.byType(BillFormScreen), findsNothing);
      expect(bills.store.values.single.title, 'Rent');
    });
  });

  group('a reminder time that has passed', () {
    const passed = "This reminder time has passed, so it won't be sent.";

    testWidgets('a new bill due today, reminded a day before, says so', (
      tester,
    ) async {
      await pumpForm(tester);
      // The folded summary doesn't promise a reminder either.
      expect(find.textContaining('Reminder time passed'), findsOneWidget);

      await openMoreOptions(tester);
      expect(find.text(passed), findsOneWidget);
    });

    testWidgets('a bill due in the future has no note', (tester) async {
      bills.store['rent'] = rent(dueDate: DateTime(2099, 1, 5));
      await pumpForm(tester, billId: 'rent');

      expect(find.text(passed), findsNothing);
      expect(find.textContaining('Reminder time passed'), findsNothing);
    });

    testWidgets('turning the reminder off removes the note', (tester) async {
      bills.store['rent'] = rent(dueDate: DateTime(2020, 1, 5));
      await pumpForm(tester, billId: 'rent');
      expect(find.text(passed), findsOneWidget);

      final toggle = find.widgetWithText(SwitchListTile, 'Remind me');
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text(passed), findsNothing);
    });
  });
}
