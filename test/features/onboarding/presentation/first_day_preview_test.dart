import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:monivo/features/onboarding/presentation/widgets/confirmation_step_widget.dart';

import '../../../integration/app_harness.dart';

/// The confirmation step's "Today's Safe Spending starts at …" comes from
/// the dashboard's engine (review: the widget divided by its own day count,
/// one day short when the start carried a time of day, and rounded up).
void main() {
  /// ₹2,400 from 8 Oct (stored as the moment onboarding ran, as older
  /// builds did) to 31 Oct: 24 calendar days, ₹100 a day.
  final draft = OnboardingState(
    budgetNameInput: 'Personal',
    monthlyBudgetInput: '2400',
    parsedBudget: 2400,
    startDate: DateTime(2026, 10, 8, 11, 20),
    endDate: DateTime(2026, 10, 31),
  );

  group('firstDaySafeToSpend', () {
    test('counts calendar days, not 24-hour spans', () {
      final firstDay = draft.firstDaySafeToSpend!;
      // The old preview: (31 Oct 00:00 − 8 Oct 11:20).inDays + 1 = 23.
      expect(firstDay.totalDays, 24);
      expect(firstDay.remainingDays, 24);
      expect(firstDay.dailySafeToSpend, closeTo(100, 1e-9));
    });

    test('is the dashboard engine\'s figure for the same budget on its '
        'first day', () async {
      final app = await AppHarness.create();
      addTearDown(app.dispose);
      await app.addBudget(
        id: 'b',
        amount: draft.parsedBudget!,
        startDate: draft.startDate,
        endDate: draft.endDate,
      );

      final dashboard =
          (await app.getSafeToSpend(
                    budgetId: 'b',
                    referenceDate: DateTime(2026, 10, 8, 9),
                  )
                  as BudgetSuccess<SafeToSpendEntity>)
              .data;

      final preview = draft.firstDaySafeToSpend!;
      expect(preview.totalDays, dashboard.totalDays);
      expect(preview.dailySafeToSpend, dashboard.dailySafeToSpend);
    });

    test('an uneven split keeps the exact quotient (display floors it)', () {
      final firstDay = draft.copyWith(parsedBudget: 1000).firstDaySafeToSpend!;
      expect(firstDay.dailySafeToSpend, closeTo(1000 / 24, 1e-9));
    });

    test('is null while the dates are invalid', () {
      final invalid = draft.copyWith(
        endDate: DateTime(2026, 10, 1),
        dateValidationError: 'End date must be after start date',
      );
      expect(invalid.firstDaySafeToSpend, isNull);
    });
  });

  group('ConfirmationStepWidget', () {
    Future<void> pump(WidgetTester tester, OnboardingState state) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: ConfirmationStepWidget(
              state: state,
              onCreateBudget: () {},
              onBack: () {},
            ),
          ),
        );

    testWidgets('shows the engine\'s day count and daily amount', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, draft);

      expect(find.textContaining('24 days'), findsWidgets);
      // The hero: the label over the figure, read as one sentence.
      expect(find.text("Today's Safe Spending starts at"), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r"^Today's Safe Spending starts at ₹100\. "),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('23 days'), findsNothing);
      semantics.dispose();
    });

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets('meets tap target, label and contrast guidelines '
          '(${theme.brightness.name})', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ConfirmationStepWidget(
                state: draft,
                onCreateBudget: () {},
                onBack: () {},
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }

    testWidgets('never rounds the daily amount up', (tester) async {
      // ₹1,000 ÷ 24 = ₹41.666…: shown as ₹41.66, never ₹42.
      final semantics = tester.ensureSemantics();
      await pump(tester, draft.copyWith(parsedBudget: 1000));

      expect(
        find.bySemanticsLabel(
          RegExp(r"^Today's Safe Spending starts at ₹41\.66\. "),
        ),
        findsOneWidget,
      );
      final hero = tester.widget<AppMoney>(
        find.byWidgetPredicate(
          (w) => w is AppMoney && w.role == MoneyRole.hero,
        ),
      );
      expect(hero.floored, isTrue);
      expect(find.textContaining('₹42'), findsNothing);
      semantics.dispose();
    });
  });
}
