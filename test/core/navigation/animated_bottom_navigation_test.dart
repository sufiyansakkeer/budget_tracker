import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/navigation/animated_bottom_navigation.dart';
import 'package:monivo/core/navigation/app_nav_destinations.dart';
import 'package:monivo/core/navigation/nav_icon_mode.dart';
import 'package:monivo/core/theme/app_theme.dart';

void main() {
  Widget harness({
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    bool reduceMotion = false,
    ThemeData? theme,
  }) {
    return NavIconMode(
      renderer: NavIconRenderer.material,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: AnimatedBottomNavigation(
              destinations: appNavDestinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders every destination with its key and label', (
    tester,
  ) async {
    await tester.pumpWidget(harness(selectedIndex: 0, onSelected: (_) {}));
    for (final d in appNavDestinations) {
      expect(find.byKey(d.key), findsOneWidget);
      expect(find.text(d.label), findsOneWidget);
    }
  });

  testWidgets('reports the tapped index, including re-taps', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(harness(selectedIndex: 1, onSelected: taps.add));

    await tester.tap(find.byKey(appNavDestinations[3].key));
    await tester.pump();
    await tester.tap(find.byKey(appNavDestinations[1].key));
    await tester.pump();

    expect(taps, [3, 1]);
  });

  testWidgets('selected destination shows the filled icon, others outlined', (
    tester,
  ) async {
    await tester.pumpWidget(harness(selectedIndex: 2, onSelected: (_) {}));
    await tester.pumpAndSettle();

    Opacity opacityOf(IconData icon) => tester.widget<Opacity>(
      find.ancestor(of: find.byIcon(icon), matching: find.byType(Opacity)),
    );

    expect(opacityOf(appNavDestinations[2].selectedIcon).opacity, 1);
    expect(opacityOf(appNavDestinations[2].icon).opacity, 0);
    expect(opacityOf(appNavDestinations[0].icon).opacity, 1);
    expect(opacityOf(appNavDestinations[0].selectedIcon).opacity, 0);
  });

  testWidgets('animates the indicator when the selection changes', (
    tester,
  ) async {
    var selected = 0;
    late StateSetter setSelected;
    await tester.pumpWidget(
      NavIconMode(
        renderer: NavIconRenderer.material,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              setSelected = setState;
              return Scaffold(
                bottomNavigationBar: AnimatedBottomNavigation(
                  destinations: appNavDestinations,
                  selectedIndex: selected,
                  onDestinationSelected: (i) => setState(() => selected = i),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    AnimatedContainer indicator(int i) => tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(appNavDestinations[i].key),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(indicator(0).constraints?.maxWidth, 64);
    expect(indicator(1).constraints?.maxWidth, 32);

    setSelected(() => selected = 1);
    await tester.pump();
    // Mid-animation the widget already targets the new sizes…
    expect(indicator(1).constraints?.maxWidth, 64);
    expect(indicator(0).constraints?.maxWidth, 32);
    // …and the animation finishes.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('settles immediately under reduced motion', (tester) async {
    await tester.pumpWidget(
      harness(selectedIndex: 0, onSelected: (_) {}, reduceMotion: true),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('semantics: buttons with labels and a selected flag', (
    tester,
  ) async {
    await tester.pumpWidget(harness(selectedIndex: 3, onSelected: (_) {}));
    final settings = tester.getSemantics(find.byKey(appNavDestinations[3].key));
    expect(settings.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(settings.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(settings.label, contains('Settings'));

    final home = tester.getSemantics(find.byKey(appNavDestinations[0].key));
    expect(home.hasFlag(SemanticsFlag.isSelected), isFalse);
  });

  testWidgets('every tap target meets the 48dp minimum', (tester) async {
    await tester.pumpWidget(harness(selectedIndex: 0, onSelected: (_) {}));
    for (final d in appNavDestinations) {
      final size = tester.getSize(find.byKey(d.key));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('uses palette colours, not hard-coded ones', (tester) async {
    await tester.pumpWidget(
      harness(selectedIndex: 0, onSelected: (_) {}, theme: AppTheme.darkTheme),
    );
    await tester.pumpAndSettle();
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AnimatedBottomNavigation),
            matching: find.byType(Material),
          )
          .first,
    );
    // The bar sits on the theme's navigation surface (Material 3's
    // surfaceContainer), never on a literal colour.
    final navTheme = AppTheme.darkTheme.navigationBarTheme;
    expect(material.color, navTheme.backgroundColor);
    expect(material.color, AppTheme.darkTheme.colorScheme.surfaceContainer);
  });
}
