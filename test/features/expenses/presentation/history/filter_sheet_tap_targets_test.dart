import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/filter_bottom_sheet.dart';

/// The filter sheet's date "×" was a 20 dp unlabelled target inside the
/// date button.
void main() {
  final filter = ExpenseHistoryFilter(
    dateFrom: DateTime(2026, 3, 2),
    dateTo: DateTime(2026, 3, 9),
  );

  Widget host() => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: FilterBottomSheet(current: filter, categories: const []),
      ),
    ),
  );

  testWidgets('meets tap target and labelling guidelines with dates set', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('each date clears on its own, keeping the other', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byTooltip('Clear start date'));
    await tester.pump();
    expect(find.text('From'), findsOneWidget);
    expect(find.text('9 Mar 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear end date'));
    await tester.pump();
    expect(find.text('To'), findsOneWidget);
    expect(find.byTooltip('Clear start date'), findsNothing);
  });

  testWidgets('both set dates fit a small phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Clear end date'), findsOneWidget);
  });
}
