import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monivo/core/biometric/app_lock_bloc.dart';
import 'package:monivo/core/biometric/app_lock_event.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_ring.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/repository/expense_repository.dart';
import 'package:monivo/main.dart';

import 'helpers/in_memory_database.dart';

/// The blueprint end to end in the real app (real router, DI and
/// database, in memory): every tab of Today | Budget | + | Activity | More
/// shows its new face for a running budget with spending today.
void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'isFirstLaunch': false});
    if (!getIt.isRegistered<SharedPreferences>()) {
      await initDependencyInjection(database: await createInMemoryDatabase());
    }
  });

  /// Lets loads finish without waiting for endless animations to settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('Today, Budget, +, Activity and More', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      final budgets = getIt<ManageBudgetUseCase>();
      await budgets.create(
        BudgetEntity(
          id: 'household',
          name: 'Household',
          monthlyAmount: 31000,
          remainingAmount: 31000,
          currency: 'INR',
          startDate: today.subtract(const Duration(days: 7)),
          endDate: DateTime(today.year, today.month, today.day + 23),
          createdAt: today,
          updatedAt: today,
        ),
      );
      await budgets.setActive('household');
      await getIt<ExpenseRepository>().createExpense(
        ExpenseEntity(
          id: 'lunch',
          budgetId: 'household',
          amount: 390,
          categoryId: 'food',
          date: today,
          time: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
    getIt<AppLockBloc>().add(const AppAuthenticated());

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartBudgetApp())),
    );
    await settle(tester);

    // Today: the ring, left today, tomorrow's amount.
    expect(find.byType(TargetRing), findsOneWidget);
    expect(find.text('Left today'), findsOneWidget);
    expect(find.text("Tomorrow's target"), findsOneWidget);

    // Budget: the active budget's period and the money map.
    await tester.tap(find.byKey(const Key('nav_budget')));
    await settle(tester);
    expect(find.text('Where the ₹31,000 is'), findsOneWidget);

    // +: every way money moves.
    await tester.tap(find.byKey(const Key('nav_add')));
    await settle(tester);
    expect(find.text('Tab payment'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40)); // the scrim closes it
    await settle(tester);
    expect(find.text('Tab payment'), findsNothing);

    // Activity: today's header carries its ring and result.
    await tester.tap(find.byKey(const Key('nav_activity')));
    await settle(tester);
    expect(find.text('Activity'), findsWidgets);
    expect(find.byType(MiniTargetRing), findsWidgets);
    expect(find.textContaining(' left'), findsWidgets);

    // More: the feature tiles.
    await tester.tap(find.byKey(const Key('nav_more')));
    await settle(tester);
    expect(find.byKey(const Key('moreTiles')), findsOneWidget);
    expect(find.text('1 running'), findsOneWidget);
  });
}
