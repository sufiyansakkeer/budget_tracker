import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/usecases/get_budget_list_summary_usecase.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_details_screen.dart';
import 'package:monivo/features/budget/presentation/pages/budget_list_screen.dart';

import '../../../../helpers/bill_ui_fakes.dart';
import '../../../../helpers/pay_later_fakes.dart';

// UX-073: the Budgets FABs were always extended and covered amounts; they
// now fold to the icon while scrolling down, as on Home and Expenses.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  BudgetEntity budget(String id, {int startIn = -5}) => BudgetEntity(
    id: id,
    name: 'Budget $id',
    monthlyAmount: 10000,
    remainingAmount: 8000,
    currency: 'INR',
    startDate: day(startIn),
    endDate: day(startIn + 30),
    createdAt: day(-40),
    updatedAt: day(-40),
  );

  Future<void> register(List<BudgetEntity> budgets, String activeId) async {
    await getIt.reset();
    final repository = ListBudgetRepository(budgets, activeId);
    getIt
      ..registerSingleton<ManageBudgetUseCase>(
        ManageBudgetUseCase(
          repository: repository,
          reconcileTabs: FakeReconcileTabUseCase(),
        ),
      )
      ..registerSingleton<BudgetRepository>(repository)
      ..registerSingleton<GetBudgetListSummaryUseCase>(
        GetBudgetListSummaryUseCase(repository: repository),
      );
  }

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: screen),
    );
    await tester.pumpAndSettle();
  }

  Finder fabLabel(String text) => find.descendant(
    of: find.byType(FloatingActionButton),
    matching: find.text(text),
  );

  Future<void> scroll(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
    await tester.pumpAndSettle();
  }

  testWidgets('the Budgets list folds "New budget" while scrolling down', (
    tester,
  ) async {
    final budgets = [
      for (var i = 0; i < 14; i++) budget('b$i', startIn: -5 - i),
    ];
    await register(budgets, 'b0');
    await pump(tester, const BudgetListScreen());
    expect(fabLabel('New budget'), findsOneWidget);

    await scroll(tester, -300);
    expect(fabLabel('New budget'), findsNothing);

    await scroll(tester, 100);
    expect(fabLabel('New budget'), findsOneWidget);
  });

  testWidgets('budget details fold "Add expense" while scrolling down', (
    tester,
  ) async {
    await register([budget('b0')], 'b0');
    await pump(tester, const BudgetDetailsScreen(budgetId: 'b0'));
    expect(fabLabel('Add expense'), findsOneWidget);

    await scroll(tester, -300);
    expect(fabLabel('Add expense'), findsNothing);

    await scroll(tester, 100);
    expect(fabLabel('Add expense'), findsOneWidget);
  });
}
