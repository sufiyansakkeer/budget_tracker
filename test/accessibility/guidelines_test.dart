import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/navigation/animated_bottom_navigation.dart';
import 'package:monivo/core/navigation/app_nav_destinations.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/contrast.dart';
import 'package:monivo/features/categories/domain/usecases/archive_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/load_categories_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/save_category_usecase.dart';
import 'package:monivo/features/categories/presentation/bloc/category_bloc.dart';
import 'package:monivo/features/categories/presentation/pages/category_management_screen.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_breakdown_card.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_notices.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_history_item.dart';

import '../features/categories/domain/usecases/category_usecases_test.dart'
    show FakeCategoryRepository, cat;
import '../features/dashboard/presentation/widgets/safe_to_spend_fixtures.dart';

/// Runs Flutter's built-in accessibility guidelines over representative
/// screens and rows. These catch the whole class of regressions the audit
/// found by hand: unlabelled controls, tap targets under the platform
/// minimum, and text that cannot be read against its background.
void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('bottom navigation', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets(
        'meets tap target, labelling and contrast guidelines ($name)',
        (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: AnimatedBottomNavigation(
                  destinations: appNavDestinations,
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }
  });

  group('category management', () {
    late FakeCategoryRepository repo;

    setUp(() {
      repo = FakeCategoryRepository();
      repo.store['food'] = cat('food', name: 'Food');
      repo.store['custom'] = cat('custom', name: 'Coffee', isSystem: false);
      repo.store['old'] = cat('old', name: 'Old', isArchived: true);
    });

    testWidgets('meets tap target and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider(
            create: (_) => CategoryBloc(
              loadCategories: LoadCategoriesUseCase(repository: repo),
              saveCategory: SaveCategoryUseCase(repository: repo),
              archiveCategory: ArchiveCategoryUseCase(repository: repo),
              deleteCategory: DeleteCategoryUseCase(repository: repo),
            ),
            child: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('expense row', () {
    final expense = ExpenseEntity(
      id: 'e1',
      budgetId: 'b1',
      amount: 250,
      categoryId: 'food',
      note: 'Pizza',
      date: DateTime(2026, 9, 10),
      time: DateTime(2026, 9, 10, 13),
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 10),
    );
    const food = ExpenseCategory(
      id: 'food',
      name: 'Food',
      icon: 'restaurant',
      colorHex: '#FF6B6B',
    );

    testWidgets('exposes tap and long-press to assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryItem(
            expense: expense,
            category: food,
            currency: 'INR',
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      );

      // A node that advertises `isButton` but carries no tap action looks
      // right and does nothing when a screen reader activates it. That is
      // what `Semantics(button: true) + ExcludeSemantics(child)` produces,
      // so the actions must sit on the node itself.
      final data = tester
          .getSemantics(find.byType(ExpenseHistoryItem))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(data.label, contains('Pizza'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      handle.dispose();
    });

    testWidgets('meets tap target and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          ExpenseHistoryItem(
            expense: expense,
            category: food,
            currency: 'INR',
            onTap: () {},
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('safe spending hero', () {
    testWidgets('meets contrast guidelines in light and dark', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          wrap(SafeSpendingHero(limit: limitFor(safeToSpend())), theme: theme),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      }
    });
  });

  group('safe-to-spend', () {
    // These widgets give each figure group one spoken label, so the visible
    // strings never equal a semantics label and `textContrastGuideline`
    // (which matches labels to Text widgets) skips them. Check every
    // visible string's effective colour against the card directly.
    void expectReadableText(WidgetTester tester, Finder root, ThemeData theme) {
      final background = theme.cardTheme.color ?? theme.colorScheme.surface;
      final texts = find.descendant(of: root, matching: find.byType(Text));
      expect(texts, findsWidgets);
      for (final element in texts.evaluate()) {
        final text = element.widget as Text;
        final style = DefaultTextStyle.of(element).style.merge(text.style);
        final color = style.color!;
        final ratio = Contrast.ratio(
          Color.alphaBlend(color, background),
          background,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(Contrast.text),
          reason: '"${text.data}" is ${ratio.toStringAsFixed(2)}:1',
        );
      }
    }

    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      for (final entry in runningStatusFixtures.entries) {
        testWidgets('hero (${entry.key}) meets contrast and tap target '
            'guidelines ($name)', (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            wrap(
              SafeSpendingHero(limit: limitFor(entry.value())),
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();
          expectReadableText(tester, find.byType(SafeSpendingHero), theme);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });
      }

      testWidgets('breakdown and forecast meet contrast and tap target '
          'guidelines, expanded ($name)', (tester) async {
        final handle = tester.ensureSemantics();
        final entity = safeToSpend(
          amount: 44000,
          periodSpent: 9000,
          reserved: 2000,
          commitments: [
            bill('rent', 12000, DateTime(2026, 8, 5), overdue: true),
            bill('phone', 500, DateTime(2026, 8, 20)),
          ],
        );
        await tester.pumpWidget(
          wrap(SafeToSpendBreakdownCard(safeToSpend: entity), theme: theme),
        );
        await tester.tap(find.textContaining('Bills due by'));
        await tester.pumpAndSettle();
        expect(find.text('Overdue'), findsOneWidget);
        expectReadableText(
          tester,
          find.byType(SafeToSpendBreakdownCard),
          theme,
        );

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('a shortfall and the notices meet contrast and tap target '
          'guidelines ($name)', (tester) async {
        final handle = tester.ensureSemantics();
        final entity = safeToSpend(
          commitments: [bill('rent', 25000, DateTime(2026, 8, 25))],
          unlinked: const UnlinkedCommitmentSummary(count: 2, total: 900),
          currencyExcluded: const CurrencyExcludedSummary(
            count: 1,
            totalsByCurrency: {'USD': 40},
          ),
        );
        await tester.pumpWidget(
          wrap(
            Column(
              children: [
                SafeToSpendBreakdownCard(safeToSpend: entity),
                SafeToSpendNotices(
                  safeToSpend: entity,
                  onLinkBills: () {},
                  onRetry: () {},
                ),
              ],
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('short'), findsWidgets);
        expectReadableText(
          tester,
          find.byType(SafeToSpendBreakdownCard),
          theme,
        );

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('other budget tile meets the guidelines ($name)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          wrap(
            OtherBudgetLimitTile(
              limit: limitFor(runningStatusFixtures['budgetAtRisk']!()),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('the bills row is a labelled, expandable button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          SafeToSpendBreakdownCard(
            safeToSpend: safeToSpend(
              commitments: [bill('rent', 12000, DateTime(2026, 8, 25))],
            ),
          ),
        ),
      );

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Bills due by 31 August')),
      );
      final data = node.getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(data.hasFlag(SemanticsFlag.hasExpandedState), isTrue);
      expect(data.hasFlag(SemanticsFlag.isExpanded), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains('1 bill, minus ₹12,000'));
      handle.dispose();
    });

    testWidgets('each breakdown row reads as one label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(SafeToSpendBreakdownCard(safeToSpend: safeToSpend(reserved: 500))),
      );

      expect(find.bySemanticsLabel('Remaining in budget, ₹22,000'), findsOne);
      expect(find.bySemanticsLabel('Kept aside, minus ₹500'), findsOne);
      expect(find.bySemanticsLabel('Savings goal, not set'), findsOne);
      expect(
        find.bySemanticsLabel('Free to spend until 31 August, ₹21,500'),
        findsOne,
      );
      handle.dispose();
    });

    testWidgets('other budget tile names its status for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(OtherBudgetLimitTile(limit: limitFor(safeToSpend(name: 'Trip')))),
      );

      final data = tester
          .getSemantics(find.byType(OtherBudgetLimitTile))
          .getSemanticsData();
      expect(data.label, 'Trip: ₹1,000 safe today, On track');
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });
}
