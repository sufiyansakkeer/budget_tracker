import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';

// UX-110: four rows each wrote `scale(14) > 20` to decide when to stack;
// they now share AppSizes.isLargeText, with the same threshold.
void main() {
  Future<bool> largeAt(WidgetTester tester, double factor) async {
    late bool large;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(factor)),
        child: Builder(
          builder: (context) {
            large = AppSizes.isLargeText(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return large;
  }

  testWidgets('stacks past about 143%, as each row did before', (tester) async {
    expect(await largeAt(tester, 1.0), isFalse);
    expect(await largeAt(tester, 1.3), isFalse);
    expect(await largeAt(tester, 1.42), isFalse);
    expect(await largeAt(tester, 1.45), isTrue);
    expect(await largeAt(tester, 2.0), isTrue);
  });
}
