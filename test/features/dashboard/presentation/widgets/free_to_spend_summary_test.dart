import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/dashboard/presentation/widgets/free_to_spend_summary.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';

import 'safe_to_spend_fixtures.dart';

// A short figure ("₹900") is what left the gap: the old 50/50 split gave it
// half the row and the chevron stopped mid-row.
final _short = safeToSpend(amount: 900);

void main() {
  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: FreeToSpendSummary(safeToSpend: _short, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('the figure sits against the chevron at ${scale}x text '
        '(review: it stopped mid-row)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, textScale: scale);

      expect(tester.takeException(), isNull);
      final value = find.text(SafeToSpendCopy.freeToSpendValue(_short));
      final chevron = find.byIcon(Icons.chevron_right_rounded);
      // The chevron closes the row at its end padding, and the figure sits
      // right against it.
      final row = tester.getRect(find.byType(FreeToSpendSummary));
      expect(
        tester.getRect(chevron).right,
        closeTo(row.right - AppSpacing.sm, 1),
      );
      expect(
        tester.getRect(value).right,
        closeTo(tester.getRect(chevron).left, 1),
      );
    });
  }
}
