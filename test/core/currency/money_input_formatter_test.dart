import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/filter_bottom_sheet.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_amount_field.dart';

/// Money fields accept grouping, and a comma decimal where the phone's
/// region uses one: a pasted "1,250.00" used to become "1".
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  Future<TextEditingController> amountField(
    WidgetTester tester, {
    int maxDecimals = 2,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        ExpenseAmountField(
          controller: controller,
          currencySymbol: r'$',
          maxDecimals: maxDecimals,
        ),
      ),
    );
    return controller;
  }

  /// What the field holds after [edit] is applied to [before], as the
  /// keyboard sends it: the whole new text with the caret at its end.
  Future<String> edit(
    WidgetTester tester,
    TextEditingController controller, {
    required String before,
    required String after,
  }) async {
    controller.value = TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: after,
        selection: TextSelection.collapsed(offset: after.length),
      ),
    );
    await tester.pump();
    return controller.text;
  }

  testWidgets('a pasted amount keeps its thousands', (tester) async {
    final controller = await amountField(tester);
    await tester.showKeyboard(find.byType(EditableText));

    for (final (pasted, kept) in [
      ('1,250.00', '1250.00'),
      ('1.250,00', '1250.00'),
      ('1,250', '1250'),
      ('1,250,000', '1250000'),
      ('1.250.000', '1250000'),
      ('1 250.5', '1250.5'),
    ]) {
      expect(
        await edit(tester, controller, before: '', after: pasted),
        kept,
        reason: pasted,
      );
    }
  });

  testWidgets('where the region uses a decimal point, a comma groups', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final controller = await amountField(tester);
    await tester.showKeyboard(find.byType(EditableText));

    // Typed key by key, "1,250" is one thousand two hundred and fifty,
    // never 1.25.
    expect(await edit(tester, controller, before: '1', after: '1,'), '1');
    expect(
      await edit(tester, controller, before: '1250', after: '1,250'),
      '1250',
    );
    expect(await edit(tester, controller, before: '', after: '12,5'), '125');
  });

  testWidgets('where the region uses a decimal comma, a comma is the point', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final controller = await amountField(tester);
    await tester.showKeyboard(find.byType(EditableText));

    expect(await edit(tester, controller, before: '27', after: '27,'), '27.');
    expect(await edit(tester, controller, before: '', after: '12,5'), '12.5');
    expect(
      await edit(tester, controller, before: '', after: '1 250,5'),
      '1250.5',
    );
    // With a point already there, a comma adds nothing.
    expect(
      await edit(tester, controller, before: '27.5', after: '27.5,'),
      '27.5',
    );
    expect(await edit(tester, controller, before: '27.', after: '27.,'), '27.');
  });

  testWidgets('the caret stays after what was typed', (tester) async {
    final controller = await amountField(tester);
    await tester.showKeyboard(find.byType(EditableText));

    await edit(tester, controller, before: '', after: '1,250.5');
    expect(controller.selection, const TextSelection.collapsed(offset: 6));
  });

  testWidgets('the currency\'s decimals still cap a comma amount', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final controller = await amountField(tester, maxDecimals: 3);
    await tester.showKeyboard(find.byType(EditableText));

    expect(
      await edit(tester, controller, before: '', after: '7,1259'),
      '7.125',
    );
  });

  testWidgets('the filter amounts accept a pasted amount', (tester) async {
    await tester.pumpWidget(
      host(
        const FilterBottomSheet(
          current: ExpenseHistoryFilter(),
          categories: [],
        ),
      ),
    );
    final min = find.widgetWithText(TextField, 'Min');
    await tester.enterText(min, '1,250.75');
    expect(tester.widget<TextField>(min).controller!.text, '1250.75');
  });
}
