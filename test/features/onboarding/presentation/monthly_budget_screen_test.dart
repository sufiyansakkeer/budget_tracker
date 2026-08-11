import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/features/onboarding/presentation/widgets/budget_step_widget.dart';

void main() {
  Widget createWidgetUnderTest({
    required String initialValue,
    required String currencySymbol,
    String? errorMessage,
    required ValueChanged<String> onChanged,
    required VoidCallback onContinue,
    required VoidCallback onBack,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: BudgetStepWidget(
          initialValue: initialValue,
          currencySymbol: currencySymbol,
          errorMessage: errorMessage,
          onChanged: onChanged,
          onContinue: onContinue,
          onBack: onBack,
        ),
      ),
    );
  }

  testWidgets(
    'Monthly Budget Screen renders prompt, currency symbol, and input field',
    (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          initialValue: '',
          currencySymbol: '₹',
          errorMessage: 'Monthly budget cannot be empty',
          onChanged: (_) {},
          onContinue: () {},
          onBack: () {},
        ),
      );

      expect(find.text('What is your budget amount?'), findsOneWidget);
      expect(find.text('₹'), findsOneWidget);
      expect(find.text('Monthly budget cannot be empty'), findsOneWidget);
    },
  );

  testWidgets(
    'Monthly Budget Screen enables continue button when input is valid without error',
    (tester) async {
      bool continuePressed = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          initialValue: '30000',
          currencySymbol: '₹',
          errorMessage: null,
          onChanged: (_) {},
          onContinue: () {
            continuePressed = true;
          },
          onBack: () {},
        ),
      );

      final continueButtonFinder = find.byKey(
        const Key('budgetStepContinueButton'),
      );
      expect(continueButtonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(continueButtonFinder);
      expect(button.enabled, isTrue);

      await tester.tap(continueButtonFinder);
      await tester.pump();

      expect(continuePressed, isTrue);
    },
  );

  testWidgets(
    'Monthly Budget Screen disables continue button when error is present',
    (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          initialValue: '-500',
          currencySymbol: '₹',
          errorMessage: 'Budget must be greater than zero',
          onChanged: (_) {},
          onContinue: () {},
          onBack: () {},
        ),
      );

      final continueButtonFinder = find.byKey(
        const Key('budgetStepContinueButton'),
      );
      final button = tester.widget<ElevatedButton>(continueButtonFinder);
      expect(button.enabled, isFalse);
    },
  );
}
