import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/widgets/app_form_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, {required double keyboard}) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: AppFormActionBar(
              child: FilledButton(
                key: const Key('save'),
                onPressed: () {},
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the save button stays above an open keyboard', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpForm(tester, keyboard: 300);

    final button = tester.getRect(find.byKey(const Key('save')));
    expect(button.bottom, lessThanOrEqualTo(800 - 300));
  });

  testWidgets('without a keyboard the button sits at the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpForm(tester, keyboard: 0);

    final button = tester.getRect(find.byKey(const Key('save')));
    expect(button.bottom, greaterThan(700));
  });
  testWidgets('on a tablet the bar lines up with the capped form (UX-062)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppFormActionBar(
            child: SizedBox(
              key: const Key('save'),
              width: double.infinity,
              height: 48,
              child: FilledButton(onPressed: () {}, child: const Text('Save')),
            ),
          ),
        ),
      ),
    );

    final button = tester.getRect(find.byKey(const Key('save')));
    expect(button.width, AppSizes.contentMaxWidth);
    expect(button.center.dx, 512);
    // Still only as tall as the bar, not the whole screen.
    expect(button.bottom, greaterThan(700));
  });
}
