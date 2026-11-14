import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/active_filter_chips.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/quick_filter_chips.dart';

void main() {
  testWidgets('All, Expenses and Bills lead the chips (blueprint)', (
    tester,
  ) async {
    final picked = <ExpenseHistoryFilter>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: QuickFilterChips(
            current: const ExpenseHistoryFilter(),
            onSelected: picked.add,
          ),
        ),
      ),
    );

    for (final label in ['All', 'Expenses', 'Bills']) {
      expect(find.byKey(Key('kindFilter_$label')), findsOneWidget);
    }
    final all = tester.widget<ChoiceChip>(
      find.byKey(const Key('kindFilter_All')),
    );
    expect(all.selected, isTrue);
    expect(
      tester.getTopLeft(find.byKey(const Key('kindFilter_Bills'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('quickFilter_Today'))).dx,
      ),
    );

    await tester.tap(find.byKey(const Key('kindFilter_Bills')));
    expect(picked.single.kind, ExpenseKind.bills);
  });

  testWidgets('an active kind is listed with the other filters, removable', (
    tester,
  ) async {
    final changed = <ExpenseHistoryFilter>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ActiveFilterChips(
            filter: const ExpenseHistoryFilter().copyWithKind(
              ExpenseKind.bills,
            ),
            categories: const [],
            onChanged: changed.add,
          ),
        ),
      ),
    );
    expect(find.text('Bills only'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Bills only filter'));
    expect(changed.single.kind, ExpenseKind.all);
  });
}
