import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/tomorrow_card.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  Widget harness(SafeToSpendEntity e) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: TomorrowCard(safeToSpend: e)),
  );

  // Fixture: 22,000 for 1–31 Aug, seen on 10 Aug: 22 days left, 1,000 a day.
  testWidgets('both of tomorrow\'s amounts, nothing more first', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(safeToSpend(periodSpent: 250, todaySpent: 250)),
    );

    expect(find.text("Tomorrow's target"), findsOneWidget);
    expect(find.text('If you spend nothing more today'), findsOneWidget);
    // 21,750 ÷ 21 = 1,035.71…, floored.
    expect(find.text('₹1,035.71'), findsOneWidget);
    expect(find.text('If you spend the rest'), findsOneWidget);
    // Spending exactly today's amount leaves tomorrow the same.
    expect(find.text('₹1,000'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('If you spend nothing more today')).dx,
      lessThan(tester.getTopLeft(find.text('If you spend the rest')).dx),
    );
  });

  testWidgets('the first outcome is highlighted (blueprint)', (tester) async {
    await tester.pumpWidget(
      harness(safeToSpend(periodSpent: 250, todaySpent: 250)),
    );
    final scheme = AppTheme.lightTheme.colorScheme;
    Color? fill(String label) => (tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.text(label),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color;
    expect(fill('If you spend nothing more today'), scheme.primaryContainer);
    expect(fill('If you spend the rest'), scheme.surfaceContainer);
  });

  testWidgets('over today: what each later day loses instead of the rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(safeToSpend(periodSpent: 1400, todaySpent: 1400)),
    );

    expect(find.text('If you spend the rest'), findsNothing);
    expect(find.text('Each later day'), findsOneWidget);
    // 400 over ÷ 21 days = 19.047…, as the hero's spread line rounds it.
    expect(find.text('−₹19.05'), findsOneWidget);
  });

  testWidgets('nothing on the last day of the period', (tester) async {
    await tester.pumpWidget(harness(safeToSpend(today: DateTime(2026, 8, 31))));
    expect(find.byType(TomorrowCard), findsOneWidget);
    expect(find.text("Tomorrow's target"), findsNothing);
  });

  testWidgets('reads each amount with its condition', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(safeToSpend(periodSpent: 250, todaySpent: 250)),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r"^Tomorrow's target\. If you spend nothing more today, "),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
