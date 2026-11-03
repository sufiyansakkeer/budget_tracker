import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/pay_later/presentation/widgets/pay_later_charts.dart';

/// Round value-axis ticks for the Pay later charts (QA F4).
void main() {
  test('ticks are 1, 2, 2.5 or 5 times a power of ten, top is a tick', () {
    expect(ChartScale.of(2.33), (interval: 1.0, max: 3.0));
    expect(ChartScale.of(0.575), (interval: 0.2, max: 0.8));
    expect(ChartScale.of(1.5), (interval: 0.5, max: 2.0));
    expect(ChartScale.of(4.25), (interval: 2.0, max: 6.0));
    expect(ChartScale.of(9), (interval: 2.5, max: 10.0));
    expect(ChartScale.of(300), (interval: 100.0, max: 400.0));
    expect(ChartScale.of(0.8), (interval: 0.2, max: 1.0));
  });

  test('the largest value never sits on the chart edge', () {
    for (final top in [0.575, 0.6, 1.5, 1.49, 2.33, 9, 10, 300, 1234.5]) {
      final scale = ChartScale.of(top.toDouble());
      expect(
        scale.max,
        greaterThanOrEqualTo(top * ChartScale.headroom),
        reason: 'top $top',
      );
    }
  });

  test('nothing to show still gives an axis', () {
    expect(ChartScale.of(0), (interval: 1.0, max: 1.0));
    expect(ChartScale.of(-2), (interval: 1.0, max: 1.0));
  });

  test('labels carry no floating-point noise', () {
    expect(ChartScale.label(0.1 + 0.2), '0.3');
    expect(ChartScale.label(3 * 0.2), '0.6');
    expect(ChartScale.label(2500), '2.5K');
  });
}
