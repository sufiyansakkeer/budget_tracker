import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/presentation/widgets/period_selector.dart';

/// UX-085: on a phone the default "This Month" chip started past the right
/// edge, so the chosen period read as cut off.
void main() {
  const width = 360.0;

  Future<void> pump(
    WidgetTester tester, {
    required ReportPeriod selected,
    bool followsBudget = false,
  }) async {
    tester.view.physicalSize = const Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PeriodSelector(
            selected: selected,
            followsBudget: followsBudget,
            onSelected: (_) {},
            onBudget: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectWhollyVisible(WidgetTester tester, String key) {
    final rect = tester.getRect(find.byKey(Key(key)));
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$key left edge');
    expect(rect.right, lessThanOrEqualTo(width), reason: '$key right edge');
  }

  double offset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('periodSelectorScroll')),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  testWidgets('the default "This Month" opens in view', (tester) async {
    await pump(tester, selected: ReportPeriod.thisMonth);
    expectWhollyVisible(tester, 'period_thisMonth');
  });

  testWidgets('a later choice scrolls into view', (tester) async {
    await pump(tester, selected: ReportPeriod.thisWeek);
    expect(offset(tester), 0, reason: 'already in view: the row stays');
    await pump(tester, selected: ReportPeriod.custom);
    expectWhollyVisible(tester, 'period_custom');
  });

  testWidgets('UX-092: the chips read in sentence case', (tester) async {
    await pump(tester, selected: ReportPeriod.thisMonth, followsBudget: true);
    for (final label in ['This budget', 'This week', 'This month']) {
      expect(find.text(label, skipOffstage: false), findsOneWidget);
    }
    expect(find.text('This Week', skipOffstage: false), findsNothing);
    expect(find.text('This Budget', skipOffstage: false), findsNothing);
  });

  testWidgets('"This Budget" first: nothing moves', (tester) async {
    await pump(tester, selected: ReportPeriod.custom, followsBudget: true);
    expect(offset(tester), 0);
    expectWhollyVisible(tester, 'period_thisBudget');
  });
}
