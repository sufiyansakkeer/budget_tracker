import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/widgets/active_budget_selector.dart';

import '../../../../helpers/haptics_recorder.dart';

/// Reads the active budget, or fails while [failing] is set.
class _FakeManageBudget implements ManageBudgetUseCase {
  bool failing = true;
  BudgetEntity? active;
  List<BudgetEntity> all = const [];
  final activated = <String>[];

  @override
  Future<BudgetEntity?> getActive() async {
    if (failing) throw Exception('database is locked');
    return active;
  }

  @override
  Future<List<BudgetEntity>> getAll({Object? options}) async => all;

  @override
  Future<String?> activeBudgetId() async => active?.id;

  @override
  Future<void> setActive(String id) async {
    activated.add(id);
    active = all.firstWhere((b) => b.id == id);
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

  BudgetEntity budget(String id, String name) => BudgetEntity(
    id: id,
    name: name,
    monthlyAmount: 1000,
    remainingAmount: 1000,
    currency: 'USD',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 31),
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  // UX-111: switching budget gave no haptic.
  testWidgets('switching budget confirms with a haptic', (tester) async {
    final personal = budget('personal', 'Personal');
    final household = budget('household', 'Household');
    manageBudget
      ..failing = false
      ..active = personal
      ..all = [personal, household];
    await pump(tester);
    final haptics = recordHaptics(tester);

    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
    await tester.tap(find.text('Household'));
    await tester.pumpAndSettle();

    expect(manageBudget.activated, ['household']);
    expect(haptics, [confirmHaptic]);
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
