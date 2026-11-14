import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/reports/domain/entities/category_analytics.dart';
import 'package:monivo/features/reports/presentation/widgets/category_treemap.dart';

void main() {
  group('treemapLayout', () {
    const area = Rect.fromLTWH(0, 0, 300, 200);

    double areaOf(Rect r) => r.width * r.height;

    test('each block\'s area is its share of the whole', () {
      final rects = treemapLayout([50, 30, 20], area);
      expect(rects, hasLength(3));
      final total = areaOf(area);
      expect(areaOf(rects[0]) / total, closeTo(0.5, 1e-9));
      expect(areaOf(rects[1]) / total, closeTo(0.3, 1e-9));
      expect(areaOf(rects[2]) / total, closeTo(0.2, 1e-9));
    });

    test('blocks fill the area without overlapping', () {
      final rects = treemapLayout([40, 25, 15, 10, 10], area);
      for (final r in rects) {
        expect(area.intersect(r), r, reason: '$r inside');
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final overlap = rects[i].intersect(rects[j]);
          expect(
            overlap.width <= 1e-9 || overlap.height <= 1e-9,
            isTrue,
            reason: '$i and $j',
          );
        }
      }
      final sum = rects.fold<double>(0, (s, r) => s + areaOf(r));
      expect(sum, closeTo(areaOf(area), 1e-6));
    });

    test('the largest comes first, along the longer side', () {
      final rects = treemapLayout([60, 40], area);
      // 300 wide: the split is left | right.
      expect(rects[0].left, 0);
      expect(rects[0].height, 200);
      expect(rects[0].width, closeTo(180, 1e-9));
    });

    test('nothing to draw for no spending', () {
      expect(treemapLayout(const [], area), isEmpty);
      expect(treemapLayout(const [0, 0], area), isEmpty);
    });
  });

  CategoryAnalytics cat(String id, double amount, double pct) =>
      CategoryAnalytics(
        categoryId: id,
        categoryName: id,
        colorHex: '#FF7043',
        totalAmount: amount,
        transactionCount: 1,
        percentageOfTotal: pct,
      );

  testWidgets('one block per category; past six the rest share "Other"', (
    tester,
  ) async {
    final analytics = [
      for (var i = 0; i < 8; i++) cat('c$i', 100.0 - i * 10, 12.5),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CategoryTreemap(analytics: analytics, currency: 'INR'),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('treemap_c0')), findsOneWidget);
    expect(find.byKey(const Key('treemap_c5')), findsOneWidget);
    expect(find.byKey(const Key('treemap_c6')), findsNothing);
    expect(find.byKey(const Key('treemap_other')), findsOneWidget);
    // The largest block says its amount and share (blueprint).
    expect(
      find.descendant(
        of: find.byKey(const Key('treemap_c0')),
        matching: find.text('₹100 · 13%'),
      ),
      findsOneWidget,
    );
  });
}
