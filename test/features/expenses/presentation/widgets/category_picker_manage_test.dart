import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_picker.dart';

/// UX-037: categories were reachable only from Settings; the picker ends
/// with a way to manage them.
void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onManage}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CategoryPicker(
            categories: defaultCategories.take(3).toList(),
            selectedCategoryId: null,
            onSelected: (_) {},
            onManage: onManage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"Manage categories" ends the chips and calls onManage', (
    tester,
  ) async {
    var opened = 0;
    await pump(tester, onManage: () => opened++);

    final manage = find.widgetWithText(ActionChip, 'Manage categories');
    expect(manage, findsOneWidget);
    // After every category chip.
    expect(
      tester.getTopLeft(manage).dy,
      greaterThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('category_fuel'))).dy,
      ),
    );

    await tester.tap(manage);
    expect(opened, 1);
  });

  testWidgets('without onManage there is no link', (tester) async {
    await pump(tester);

    expect(find.text('Manage categories'), findsNothing);
  });
}
