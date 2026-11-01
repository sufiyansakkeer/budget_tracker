import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/active_filter_chips.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/filter_bottom_sheet.dart';

/// An amount filter keeps its decimals: 12.5 used to reopen as "13", and
/// Apply then saved 13.
void main() {
  const filter = ExpenseHistoryFilter(minAmount: 12.5, maxAmount: 99.99);

  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('the filter sheet reopens with the exact amounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const FilterBottomSheet(current: filter, categories: [])),
    );

    final texts = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text);
    expect(texts, containsAll(['12.5', '99.99']));
  });

  testWidgets('the chips show the exact amounts', (tester) async {
    await tester.pumpWidget(
      host(
        ActiveFilterChips(
          filter: filter,
          categories: const [],
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Min 12.5'), findsOneWidget);
    expect(find.text('Max 99.99'), findsOneWidget);
  });
}
