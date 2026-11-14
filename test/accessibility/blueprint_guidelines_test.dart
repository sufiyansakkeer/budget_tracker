import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_period_view.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/navigation/animated_bottom_navigation.dart';
import 'package:monivo/core/navigation/app_nav_destinations.dart';
import 'package:monivo/core/navigation/nav_add_button.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/day_target.dart';
import 'package:monivo/features/budget/presentation/widgets/money_map.dart';
import 'package:monivo/features/dashboard/presentation/widgets/budget_chips.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';
import 'package:monivo/features/dashboard/presentation/widgets/tomorrow_card.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_group.dart';
import 'package:monivo/features/expenses/presentation/add/add_sheet.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_group_header.dart';
import 'package:monivo/features/expenses/presentation/widgets/today_impact.dart';
import 'package:monivo/features/settings/presentation/widgets/more_tiles.dart';

import '../features/dashboard/presentation/widgets/safe_to_spend_fixtures.dart';

/// Every surface the blueprint added, in every palette and both modes:
/// tap targets, labels and text contrast (the theme contrast contract).
void main() {
  final under = safeToSpend(periodSpent: 570, todaySpent: 570);
  final over = safeToSpend(periodSpent: 1400, todaySpent: 1400);
  final day = DateTime(2026, 8, 9);

  Widget surfaces() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BudgetChips(
          limits: [
            limitFor(under),
            limitFor(safeToSpend(budgetId: 'b2', name: 'Personal')),
          ],
          activeBudgetId: 'b1',
          onSelect: (_) {},
          onOpenActive: () {},
        ),
        SafeSpendingHero(limit: limitFor(under), onShowWorking: () {}),
        SafeSpendingHero(limit: limitFor(over)),
        TomorrowCard(safeToSpend: under),
        TomorrowCard(safeToSpend: over),
        TodayImpact(before: safeToSpend(), after: under),
        TodayImpact(before: under, after: over),
        // The Budget tab, its sheet and the add sheet.
        BudgetPeriodView(
          budget: _budgetOf(under),
          e: under,
          expenseCount: 3,
          others: const [],
          onShowWorking: () {},
          onChangeTarget: () {},
          onOpenBills: () {},
          onOpenSpent: () {},
          onAllBudgets: () {},
          onOpenOther: (_) {},
        ),
        MoneyMap(safeToSpend: under),
        ExpenseGroupHeader(
          group: ExpenseGroup(
            type: ExpenseGroupType.earlier,
            date: day,
            expenses: [
              ExpenseEntity(
                id: 'x',
                budgetId: 'b1',
                amount: 1200,
                categoryId: 'food',
                date: day,
                time: day,
                createdAt: day,
                updatedAt: day,
              ),
            ],
          ),
          currency: 'INR',
          dayTarget: DayTarget(
            date: day,
            target: 1000,
            spent: 1200,
            result: -200,
          ),
        ),
        MoreTiles(load: () async => MoreTileValues.fallback, onData: () {}),
        const AddSheet(),
      ],
    ),
  );

  for (final palette in ColorPalette.values) {
    for (final dark in [false, true]) {
      final name = '${palette.name} ${dark ? 'dark' : 'light'}';
      testWidgets('blueprint surfaces meet the guidelines ($name)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 7400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark
                ? AppTheme.buildDarkTheme(palette)
                : AppTheme.buildLightTheme(palette),
            home: Scaffold(
              body: surfaces(),
              bottomNavigationBar: AnimatedBottomNavigation(
                destinations: appNavDestinations,
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                center: NavAddButton(onPressed: () {}, onLongPress: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }
}

BudgetEntity _budgetOf(SafeToSpendEntity e) => BudgetEntity(
  id: e.budgetId,
  name: e.budgetName,
  monthlyAmount: e.budgetAmount,
  remainingAmount: e.availableBalance,
  currency: e.currency,
  startDate: e.startDate,
  endDate: e.endDate,
  createdAt: e.startDate,
  updatedAt: e.startDate,
);
