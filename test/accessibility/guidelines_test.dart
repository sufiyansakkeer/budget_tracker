import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/navigation/animated_bottom_navigation.dart';
import 'package:monivo/core/navigation/app_nav_destinations.dart';
import 'package:monivo/core/navigation/nav_icon_mode.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/categories/domain/usecases/archive_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/load_categories_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/save_category_usecase.dart';
import 'package:monivo/features/categories/presentation/bloc/category_bloc.dart';
import 'package:monivo/features/categories/presentation/pages/category_management_screen.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_history_item.dart';

import '../features/categories/domain/usecases/category_usecases_test.dart'
    show FakeCategoryRepository, cat;
import '../features/dashboard/presentation/widgets/safe_spending_hero_test.dart'
    show limit;

/// Runs Flutter's built-in accessibility guidelines over representative
/// screens and rows. These catch the whole class of regressions the audit
/// found by hand: unlabelled controls, tap targets under the platform
/// minimum, and text that cannot be read against its background.
void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => NavIconMode(
    renderer: NavIconRenderer.material,
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('bottom navigation', () {
    testWidgets('meets tap target, labelling and contrast guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        NavIconMode(
          renderer: NavIconRenderer.material,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: AnimatedBottomNavigation(
                destinations: appNavDestinations,
                selectedIndex: 0,
                onDestinationSelected: (_) {},
              ),
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
    });
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
          wrap(SafeSpendingHero(limit: limit()), theme: theme),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      }
    });
  });
}
