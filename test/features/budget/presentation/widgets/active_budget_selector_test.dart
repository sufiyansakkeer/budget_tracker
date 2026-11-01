import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/widgets/active_budget_selector.dart';

/// Reads the active budget, or fails while [failing] is set.
class _FakeManageBudget implements ManageBudgetUseCase {
  bool failing = true;
  BudgetEntity? active;

  @override
  Future<BudgetEntity?> getActive() async {
    if (failing) throw Exception('database is locked');
    return active;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeManageBudget manageBudget;

  setUp(() async {
    await getIt.reset();
    manageBudget = _FakeManageBudget();
    getIt.registerSingleton<ManageBudgetUseCase>(manageBudget);
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: ActiveBudgetSelector()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a budget that could not be read says so, not "none selected"', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text("Couldn't load your budget"), findsOneWidget);
    expect(find.text('No active budget selected'), findsNothing);
  });

  testWidgets('tapping it reads the budget again', (tester) async {
    await pump(tester);
    manageBudget
      ..failing = false
      ..active = BudgetEntity(
        id: 'personal',
        name: 'Personal',
        monthlyAmount: 1000,
        remainingAmount: 1000,
        currency: 'USD',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

    await tester.tap(find.text("Couldn't load your budget"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Personal'), findsOneWidget);
  });
}
