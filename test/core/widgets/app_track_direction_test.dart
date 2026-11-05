import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/widgets/app_track.dart';

/// UX-113: AppTrack fills, and places its markers, from the start edge, so
/// a right-to-left layout mirrors it and a left-to-right one is unchanged.
void main() {
  const width = 200.0;
  const fill = Color(0xFF00AA00);
  const marker = Color(0xFFAA0000);

  Future<({Rect track, Rect fill, Rect marker})> pump(
    WidgetTester tester,
    TextDirection direction,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: AppTrack(
              value: 0.25,
              color: fill,
              markers: [TrackMarker(position: 0.6, color: marker)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Rect boxWith(Color color) => tester.getRect(
      find
          .byWidgetPredicate(
            (w) =>
                (w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).color == color) ||
                (w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).color == color),
          )
          .first,
    );
    return (
      track: tester.getRect(find.byType(AppTrack)),
      fill: boxWith(fill),
      marker: boxWith(marker),
    );
  }

  testWidgets('left to right: fills from the left, as before', (tester) async {
    final r = await pump(tester, TextDirection.ltr);
    expect(r.fill.left, r.track.left);
    expect(r.fill.width, width * 0.25);
    // The marker's centre sits at 60% from the left (2 px wide).
    expect(r.marker.left - r.track.left, width * 0.6 - 1);
  });

  testWidgets('right to left: the same track, mirrored', (tester) async {
    final ltr = await pump(tester, TextDirection.ltr);
    final rtl = await pump(tester, TextDirection.rtl);

    expect(rtl.fill.right, rtl.track.right);
    expect(rtl.fill.width, ltr.fill.width);
    expect(rtl.fill.top, ltr.fill.top);
    // Every edge is the left-to-right one reflected across the track.
    double mirror(double x) => rtl.track.left + rtl.track.right - x;
    expect(rtl.fill.left, mirror(ltr.fill.right));
    expect(rtl.marker.left, mirror(ltr.marker.right));
    expect(rtl.marker.size, ltr.marker.size);
  });
}
