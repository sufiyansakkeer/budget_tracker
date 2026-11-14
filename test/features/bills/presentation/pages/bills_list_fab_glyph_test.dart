import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_bloc.dart';
import 'package:monivo/features/bills/presentation/pages/bills_list_screen.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';
import '../../../../helpers/safe_to_spend_fakes.dart';

// UX-073 (the add button folds on scroll here too) and UX-108 (inline
// glyphs grow with the text).
void main() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  BillEntity bill(String id, int dueIn, {bool recurring = false}) => BillEntity(
    id: id,
    title: 'Bill $id',
    amount: 100,
    currency: 'INR',
    category: BillCategory.electricity,
    dueDate: day(dueIn),
    isPaid: false,
    isRecurring: recurring,
    recurrenceType: recurring ? RecurrenceType.monthly : RecurrenceType.none,
    reminderEnabled: false,
    createdAt: day(-30),
    updatedAt: day(-30),
  );

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

  Future<void> pump(
    WidgetTester tester,
    List<BillEntity> bills, {
    double textScale = 1,
  }) async {
    const size = Size(400, 800);
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

  testWidgets('the add button folds to its icon while the list scrolls down '
      '(review: always extended, over the amounts)', (tester) async {
    await pump(tester, [for (var i = 0; i < 20; i++) bill('b$i', i + 1)]);
    final label = find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.text('Add bill'),
    );
    expect(label, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(label, findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
  });

  testWidgets('with large text the row keeps its status in words, without '
      'overflowing (blueprint: no inline glyphs)', (tester) async {
    await pump(tester, [bill('rent', 3, recurring: true)], textScale: 2);
    expect(
      find.textContaining('Due in 3 days', findRichText: true),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
