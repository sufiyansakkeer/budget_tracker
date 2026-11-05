import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/free_to_spend_summary.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';

import 'safe_to_spend_fixtures.dart';

// A short figure ("₹900") is what left the gap: the old 50/50 split gave it
// half the row and the chevron stopped mid-row.
final _short = safeToSpend(amount: 900);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    SafeToSpendEntity? entity,
  }) async {
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
              child: FreeToSpendSummary(
                safeToSpend: entity ?? _short,
                onTap: () {},
              ),
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

  group('large text (UX-072)', () {
    // A six-figure amount is what squeezed the label to about 7 lines.
    final wide = safeToSpend(amount: 2200000);

    testWidgets('at 2x text the figure moves under the label instead of '
        'squeezing it into a narrow column', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, textScale: 2, entity: wide);

      expect(tester.takeException(), isNull);
      final value = find.text(SafeToSpendCopy.freeToSpendValue(wide));
      final detail = find.text(SafeToSpendCopy.freeToSpendContext(wide));
      final row = tester.getRect(find.byType(FreeToSpendSummary));
      final chevron = tester.getRect(find.byIcon(Icons.chevron_right_rounded));
      expect(
        tester.getRect(value).top,
        greaterThanOrEqualTo(tester.getRect(detail).bottom),
      );
      // The label has the row's whole width beside the chevron.
      expect(
        tester.getRect(detail).width,
        greaterThan((row.width - chevron.width) * 0.7),
      );
      // The figure still ends against the chevron.
      expect(tester.getRect(value).right, closeTo(chevron.left, 1));
    });

    testWidgets('at normal text the figure stays beside the label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, entity: wide);

      final value = find.text(SafeToSpendCopy.freeToSpendValue(wide));
      final title = find.text('Free to spend');
      expect(
        tester.getRect(value).left,
        greaterThan(tester.getRect(title).right),
      );
    });
  });
}
