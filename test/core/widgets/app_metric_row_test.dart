import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_metric.dart';
import 'package:monivo/core/widgets/app_money.dart';

/// UX-054: three metrics side by side broke labels mid-word and ran values
/// together at large text ("Expense/s", "₹2,763 13").
void main() {
  Future<void> pump(WidgetTester tester, {required double textScale}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AppMetricRow(
                metrics: [
                  AppMetric(
                    label: 'Spent',
                    value: AppMoney(amount: 9, currency: 'USD'),
                  ),
                  AppMetric(
                    label: 'Spent today, incl. bills',
                    value: AppMoney(amount: 5, currency: 'USD'),
                  ),
                  AppMetric(
                    label: 'Expenses',
                    alignEnd: true,
                    value: Text('13'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool truncated(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  testWidgets('side by side with gutters at normal text', (tester) async {
    await pump(tester, textScale: 1);
    final spent = tester.getTopLeft(find.text('Spent'));
    final count = tester.getTopLeft(find.text('Expenses'));
    expect(count.dy, spent.dy);
    // A gutter between the columns, so values never touch.
    expect(
      tester.getTopLeft(find.byType(AppMetric).at(1)).dx -
          tester.getTopRight(find.byType(AppMetric).at(0)).dx,
      greaterThanOrEqualTo(12),
    );
  });

  testWidgets('stacks at 200% text: no label is cut, no values run '
      'together', (tester) async {
    await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final spent = tester.getTopLeft(find.text('Spent'));
    final today = tester.getTopLeft(find.text('Spent today, incl. bills'));
    final count = tester.getTopLeft(find.text('Expenses'));
    expect(today.dy, greaterThan(spent.dy));
    expect(count.dy, greaterThan(today.dy));
    // Stacked, every metric starts at the same edge.
    expect(count.dx, spent.dx);
    expect(truncated(tester, 'Spent today, incl. bills'), isFalse);
    expect(truncated(tester, 'Expenses'), isFalse);
  });
}
