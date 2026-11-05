import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_amount_field.dart';
import 'package:monivo/core/widgets/primary_button.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_picker_sheet.dart';
import 'package:monivo/features/settings/domain/entities/currency_entity.dart';
import 'package:monivo/features/settings/presentation/widgets/currency_selector.dart';

/// UX-110 (deferred part): one amount field, one Save, one budget picker
/// and one currency picker, where there were 5+, 5, 2 and 3.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  /// Every Dart file under lib/, with its path relative to the repo.
  Iterable<(String, String)> libFiles() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield (entity.path, entity.readAsStringSync());
      }
    }
  }

  group('AppAmountField', () {
    TextField textField(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(
        of: find.byType(AppAmountField),
        matching: find.byType(TextField),
      ),
    );

    testWidgets('no symbol at all while the currency is unknown', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(AppAmountField(controller: controller, currency: null)),
      );
      expect(textField(tester).decoration!.prefixText, isNull);
    });

    testWidgets('an unknown code shows the code, never a stand-in ₹', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(AppAmountField(controller: controller, currency: 'XYZ')),
      );
      expect(textField(tester).decoration!.prefixText, 'XYZ ');
    });

    testWidgets('types at the currency precision, hinted the same way', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(AppAmountField(controller: controller, currency: 'OMR')),
      );
      final field = textField(tester);
      expect(
        field.decoration!.prefixText,
        '${CurrencyFormatter.symbolFor('OMR')} ',
      );
      expect(field.decoration!.hintText, '0.000');
      expect(field.decoration!.labelText, 'Amount');

      await tester.enterText(find.byType(AppAmountField), '7.12599');
      expect(controller.text, '7.125');
      await tester.enterText(find.byType(AppAmountField), '1,250.5');
      expect(controller.text, '1250.5');
    });

    testWidgets("a screen's own rules run through its form", (tester) async {
      final controller = TextEditingController(text: '0');
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: form,
            child: AppAmountField(
              controller: controller,
              currency: 'INR',
              validator: (v) => v == '0' ? 'Enter more than 0' : null,
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter more than 0'), findsOneWidget);
    });

    testWidgets('the theme decoration, not a field drawn by hand', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(AppAmountField(controller: controller, currency: 'INR')),
      );
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      final theme = AppTheme.lightTheme.inputDecorationTheme;
      expect(decorator.decoration.border, theme.border);
      expect(decorator.decoration.filled, theme.filled);
    });

    test('every money field in lib/ is AppAmountField', () {
      final offenders = <String>[
        for (final (path, source) in libFiles())
          if (!path.endsWith('app_amount_field.dart') &&
              !path.endsWith('money_input_formatter.dart') &&
              (source.contains('numberWithOptions(') ||
                  source.contains('MoneyInputFormatter(')))
            path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('PrimaryButton, every Save', () {
    Color? background(WidgetTester tester) => tester
        .widget<FilledButton>(find.byKey(const Key('save')))
        .style
        ?.backgroundColor
        ?.resolve({WidgetState.disabled});

    testWidgets('busy: primary, a spinner, and taps do nothing', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          PrimaryButton(
            buttonKey: const Key('save'),
            label: 'Save changes',
            icon: Icons.check_rounded,
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('save'))).onPressed,
        isNull,
      );
      expect(background(tester), AppTheme.lightTheme.colorScheme.primary);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('save')), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('saved: a check mark and "Saved", still primary', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PrimaryButton(
            buttonKey: const Key('save'),
            label: 'Add expense',
            icon: Icons.add_rounded,
            isDone: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(background(tester), AppTheme.lightTheme.colorScheme.primary);
    });

    testWidgets('the icon comes before the label', (tester) async {
      await tester.pumpWidget(
        host(
          PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.arrow_forward_rounded)).dx,
        lessThan(tester.getCenter(find.text('Continue')).dx),
      );
    });

    test('forms and sheets save through PrimaryButton', () {
      const saves = [
        'lib/features/expenses/presentation/pages/expense_form_screen.dart',
        'lib/features/expenses/presentation/quick_add/quick_add_sheet.dart',
        'lib/features/budget/presentation/pages/budget_form_screen.dart',
        'lib/features/bills/presentation/pages/bill_form_screen.dart',
        'lib/features/pay_later/presentation/pages/tab_form_screen.dart',
        'lib/features/pay_later/presentation/widgets/payment_sheet.dart',
        'lib/features/categories/presentation/widgets/category_form_sheet.dart',
        'lib/features/onboarding/presentation/widgets/onboarding_step_layout.dart',
      ];
      for (final path in saves) {
        expect(
          File(path).readAsStringSync(),
          contains('PrimaryButton('),
          reason: path,
        );
      }
      final elevated = [
        for (final (path, source) in libFiles())
          if (!path.contains('/theme/') && source.contains('ElevatedButton('))
            path,
      ];
      expect(elevated, isEmpty);
    });
  });

  group('CurrencySelector.show, the one currency picker', () {
    testWidgets('returns the pick and closes only its own sheet', (
      tester,
    ) async {
      final results = <CurrencyEntity?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/form': (_) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => results.add(
                    await CurrencySelector.show(
                      context,
                      title: 'Currency',
                      selectedCode: 'INR',
                    ),
                  ),
                  child: const Text('Pick'),
                ),
              ),
            ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/form');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CurrencyListTile, 'USD'));
      await tester.pumpAndSettle();

      expect(results.single?.code, 'USD');
      // The form under the sheet is still open: no second pop.
      expect(find.text('Pick'), findsOneWidget);
    });

    test('no screen builds its own currency list', () {
      final offenders = [
        for (final (path, source) in libFiles())
          if (!path.endsWith('currency_selector.dart') &&
              (source.contains('CurrencySelector(') ||
                  RegExp(
                    r'DropdownMenuItem[^;]*\.code',
                    dotAll: true,
                  ).hasMatch(source)))
            path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('BudgetPickerSheet, the one budget picker', () {
    BudgetEntity budget(String id, {bool archived = false}) => BudgetEntity(
      id: id,
      name: id,
      monthlyAmount: 100,
      remainingAmount: 100,
      currency: 'INR',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      isArchived: archived,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    testWidgets('a budget that can\'t be picked says why, and stays put', (
      tester,
    ) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await BudgetPickerSheet.show<String>(
                    context,
                    title: 'Pick',
                    budgets: [budget('a'), budget('b')],
                    selectedId: 'a',
                    disabledReason: (b) => b.id == 'b' ? 'Uses USD' : null,
                    onPick: (b) => 'pick ${b.id}',
                    onOpen: (b) => 'open ${b.id}',
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Uses USD'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);

      await tester.tap(find.byTooltip('Budget details').first);
      await tester.pumpAndSettle();
      expect(results, ['open a']);
    });

    test('the switcher and the move sheet both use it', () {
      for (final path in [
        'lib/features/budget/presentation/widgets/active_budget_selector.dart',
        'lib/features/expenses/presentation/widgets/move_expense_sheet.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('BudgetPickerSheet.show'),
          reason: path,
        );
      }
    });
  });
}
