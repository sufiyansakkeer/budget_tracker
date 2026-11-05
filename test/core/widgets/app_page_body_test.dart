import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/widgets/app_list.dart';
import 'package:monivo/core/widgets/app_page_body.dart';

void main() {
  /// Pumps an [AppPageBody] on a [width]-wide screen with [safe] insets and
  /// returns the padding it hands its scroll view.
  Future<EdgeInsets> resolve(
    WidgetTester tester, {
    required double width,
    EdgeInsets safe = EdgeInsets.zero,
    bool bottomBar = false,
    EdgeInsets padding = AppSpacing.pagePadding,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    late EdgeInsets resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800), padding: safe),
          child: Scaffold(
            body: AppPageBody(
              padding: padding,
              builder: (context, p) {
                resolved = p;
                return ListView(padding: p);
              },
            ),
            bottomNavigationBar: bottomBar ? const SizedBox(height: 56) : null,
          ),
        ),
      ),
    );
    return resolved;
  }

  group('AppPageBody', () {
    testWidgets('leaves a phone\'s padding as it is', (tester) async {
      expect(await resolve(tester, width: 360), AppSpacing.pagePadding);
    });

    testWidgets('centres the content at the max width on a tablet', (
      tester,
    ) async {
      final p = await resolve(tester, width: 1024);
      expect(1024 - p.left - p.right, AppSizes.contentMaxWidth);
      expect(p.left, p.right);
      expect(p.top, AppSpacing.md);
      expect(p.bottom, AppSpacing.md);
    });

    testWidgets('adds the side and bottom safe-area insets (UX-063)', (
      tester,
    ) async {
      final p = await resolve(
        tester,
        width: 400,
        safe: const EdgeInsets.fromLTRB(44, 24, 30, 34),
      );
      expect(p.left, AppSpacing.md + 44);
      expect(p.right, AppSpacing.md + 30);
      expect(p.bottom, AppSpacing.md + 34);
      // The top is the app bar's (here, the Scaffold has none: still not
      // added, a page body never draws under the status bar on its own).
      expect(p.top, AppSpacing.md);
    });

    testWidgets('a landscape notch wider than the gutter wins', (tester) async {
      final p = await resolve(
        tester,
        width: 800,
        safe: const EdgeInsets.only(left: 100),
      );
      expect(p.left, AppSpacing.md + 100);
      expect(p.right, (800 - AppSizes.contentMaxWidth) / 2);
    });

    testWidgets('an inset the bottom bar already clears is not added again', (
      tester,
    ) async {
      final p = await resolve(
        tester,
        width: 400,
        safe: const EdgeInsets.only(bottom: 34),
        bottomBar: true,
      );
      expect(p.bottom, AppSpacing.md);
    });
  });

  group('AppListRow trailing cap (UX-062)', () {
    Widget row() => const AppListRow(
      title: 'Electricity',
      trailing: SizedBox(key: Key('amount'), width: 1000, height: 20),
    );

    testWidgets('is measured from the row, not the screen', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: 400, child: row())),
          ),
        ),
      );
      final amount = tester.getRect(find.byKey(const Key('amount')));
      expect(amount.width, closeTo(400 * 0.46, 0.01));
      expect(amount.right, closeTo(800, 0.01));
      expect(tester.getRect(find.text('Electricity')).left, closeTo(400, 0.01));
    });

    testWidgets('right to left, the amount sits at the start', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: row()),
          ),
        ),
      );
      final amount = tester.getRect(find.byKey(const Key('amount')));
      expect(amount.left, 0);
      expect(amount.width, closeTo(400 * 0.46, 0.01));
    });

    testWidgets('still measures its intrinsics, as a dialog does', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IntrinsicWidth(
                child: IntrinsicHeight(
                  child: AppListRow(
                    title: 'Electricity',
                    subtitle: 'In 4 days',
                    trailing: const Text('1,850'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AppListRow)).height,
        greaterThanOrEqualTo(AppSizes.listRowHeight),
      );
      expect(find.text('1,850'), findsOneWidget);
    });
  });

  test('every page body listed in UX-062 uses AppPageBody', () {
    const pages = [
      'lib/features/expenses/presentation/history/pages/expense_history_screen.dart',
      'lib/features/expenses/presentation/pages/expense_details_screen.dart',
      'lib/features/expenses/presentation/pages/expense_form_screen.dart',
      'lib/features/settings/presentation/pages/settings_screen.dart',
      'lib/features/settings/presentation/pages/palette_selection_screen.dart',
      'lib/features/budget/presentation/pages/budget_list_screen.dart',
      'lib/features/budget/presentation/pages/budget_details_screen.dart',
      'lib/features/budget/presentation/pages/budget_form_screen.dart',
      'lib/features/bills/presentation/pages/bills_list_screen.dart',
      'lib/features/bills/presentation/pages/bill_details_screen.dart',
      'lib/features/bills/presentation/pages/bill_form_screen.dart',
      'lib/features/categories/presentation/pages/category_management_screen.dart',
      'lib/features/onboarding/presentation/pages/onboarding_screen.dart',
      'lib/features/pay_later/presentation/pages/pay_later_overview_screen.dart',
      'lib/features/pay_later/presentation/pages/tab_detail_screen.dart',
      'lib/features/pay_later/presentation/pages/tab_form_screen.dart',
      'lib/features/currency_converter/presentation/pages/currency_converter_screen.dart',
    ];
    final missing = [
      for (final page in pages)
        if (!File(page).readAsStringSync().contains('AppPageBody(')) page,
    ];
    expect(missing, isEmpty);
  });
}
