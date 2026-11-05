import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/core/widgets/app_color_swatch.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_visuals.dart';
import 'package:monivo/features/categories/domain/entities/category_catalog.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_visuals.dart';

// UX-110: the budget form and the category sheet each had their own colour
// swatch. UX-107: both picked the check mark's colour by estimated
// brightness, which leaves a white mark under 3:1 on mid-tone fills.
void main() {
  group('check mark', () {
    test('a mid-tone fill gets a mark that reaches 3:1', () {
      const fill = Color(0xFF999999);
      // The old rule: estimated "dark", so a white mark at about 2.8:1.
      expect(ThemeData.estimateBrightnessForColor(fill), Brightness.dark);
      expect(Contrast.ratio(Colors.white, fill), lessThan(Contrast.large));

      final mark = AppColorSwatch.checkColorOn(fill);
      expect(Contrast.ratio(mark, fill), greaterThanOrEqualTo(Contrast.large));
    });

    test('white stays white wherever it is legible', () {
      const navy = Color(0xFF1E3A8A);
      expect(AppColorSwatch.checkColorOn(navy), Colors.white);
    });

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets('every offered colour carries a legible mark '
          '(${theme.brightness.name})', (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        final fills = [
          for (final (hex, _) in BudgetVisuals.colorOptions)
            BudgetVisuals.rawColor(hex),
          for (final hex in CategoryCatalog.colorHexes)
            CategoryVisuals.adaptiveColor(context, hex),
        ];
        for (final fill in fills) {
          expect(
            Contrast.ratio(AppColorSwatch.checkColorOn(fill), fill),
            greaterThanOrEqualTo(Contrast.large),
            reason: '$fill',
          );
        }
      });
    }
  });

  testWidgets('one selectable button per colour, with its name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: AppColorSwatch(
              color: const Color(0xFF999999),
              name: 'Grey',
              selected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(AppColorSwatch));
    expect(node.label, 'Grey colour');
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(
      Contrast.ratio(icon.color!, const Color(0xFF999999)),
      greaterThanOrEqualTo(Contrast.large),
    );

    await tester.tap(find.byType(AppColorSwatch));
    expect(taps, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
