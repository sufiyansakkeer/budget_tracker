import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_motion.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/theme/app_colors_extension.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/app_tone.dart';
import 'package:monivo/core/widgets/app_list.dart';
import 'package:monivo/core/widgets/app_metric.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_section.dart';
import 'package:monivo/core/widgets/app_track.dart';
import 'package:monivo/core/widgets/status_chip.dart';

void main() {
  Widget harness(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  group('AppMetric', () {
    testWidgets('reads as one phrase: label then value', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          const AppMetric(
            label: 'Spent today',
            value: AppMoney(amount: 570, currency: 'INR'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppMetric)),
        matchesSemantics(label: 'Spent today\n₹570'),
      );
      handle.dispose();
    });
  });

  group('AppSection', () {
    testWidgets('marks its title as a header and shows the action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          AppSection(
            title: 'Coming up',
            action: TextButton(onPressed: () {}, child: const Text('See all')),
            child: const Text('rows'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Coming up')),
        matchesSemantics(label: 'Coming up', isHeader: true),
      );
      expect(find.text('See all'), findsOneWidget);
      // No card: nothing in a section paints a border or a fill.
      expect(find.byType(Card), findsNothing);
      handle.dispose();
    });
  });

  group('AppListRow', () {
    testWidgets('a tappable row is one labelled button at least 56 dp tall', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        harness(
          AppListRow(
            title: 'Electricity',
            subtitle: 'In 4 days',
            trailing: const AppMoney(amount: 1850, currency: 'INR'),
            onTap: () => taps++,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppListRow)).height,
        greaterThanOrEqualTo(AppSizes.listRowHeight),
      );
      expect(
        tester.getSemantics(find.byType(AppListRow)),
        matchesSemantics(
          label: 'Electricity, In 4 days',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Electricity'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a grouped list puts a hairline between rows only', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const AppGroupedList(
            children: [
              AppListRow(title: 'One'),
              AppListRow(title: 'Two'),
              AppListRow(title: 'Three'),
            ],
          ),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('AppTrack', () {
    testWidgets('clamps its value, speaks it, and draws its markers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 200,
            child: AppTrack(
              value: 1.4,
              color: Colors.orange,
              semanticLabel: 'Spent today',
              markers: [TrackMarker(position: 0.25, color: Colors.black)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(AppTrack)),
        matchesSemantics(label: 'Spent today', value: '100%'),
      );
      // Track + fill + one marker.
      expect(
        find.descendant(
          of: find.byType(AppTrack),
          matching: find.byType(Positioned),
        ),
        findsNWidgets(3),
      );
      handle.dispose();
    });
  });

  group('StatusChip.tone', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('draws with the tone container and its text colour ($name)', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            const StatusChip.tone(
              label: 'At risk',
              tone: AppTone.caution,
              icon: Icons.trending_down_rounded,
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        final tone = theme.extension<AppColorTokens>()!.tone(AppTone.caution);
        final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect((box.decoration! as BoxDecoration).color, tone.container);
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.trending_down_rounded),
        );
        expect(icon.color, tone.onContainer);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  });

  group('AppMotion.isReduced', () {
    testWidgets('honours iOS Reduce Motion as well as disableAnimations', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(AppMotion.isReduced(captured), isFalse);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      expect(AppMotion.isReduced(captured), isTrue);
      expect(
        AppMotion.respectReducedMotion(captured, AppMotion.standard),
        Duration.zero,
      );
    });
  });
}
