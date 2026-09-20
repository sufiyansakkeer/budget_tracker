import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/categories/domain/usecases/archive_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/load_categories_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/save_category_usecase.dart';
import 'package:monivo/features/categories/presentation/bloc/category_bloc.dart';
import 'package:monivo/features/categories/presentation/pages/category_management_screen.dart';
import 'package:monivo/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';

import '../../domain/usecases/category_usecases_test.dart'
    show FakeCategoryRepository, cat;

void main() {
  group('CategoryFormSheet', () {
    /// Opens the sheet and returns a getter for the value it popped with.
    Future<CategoryDraft? Function()> openSheet(
      WidgetTester tester, {
      ExpenseCategory? category,
      List<ExpenseCategory> existing = const [],
    }) async {
      CategoryDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await CategoryFormSheet.show(
                    context,
                    category: category,
                    existing: existing,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.byKey(const Key('saveCategoryButton'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('shows inline error for an empty name', (tester) async {
      await openSheet(tester);
      await tapSave(tester);
      expect(find.text('Name cannot be empty'), findsOneWidget);
      expect(find.byType(CategoryFormSheet), findsOneWidget);
    });

    testWidgets('shows inline error for a duplicate name', (tester) async {
      await openSheet(tester, existing: [cat('food', name: 'Food')]);
      await tester.enterText(
        find.byKey(const Key('categoryNameField')),
        'food',
      );
      await tester.pumpAndSettle();
      await tapSave(tester);
      expect(
        find.text('A category with this name already exists'),
        findsOneWidget,
      );
    });

    testWidgets('returns the draft with chosen icon and colour', (
      tester,
    ) async {
      final result = await openSheet(tester);

      await tester.enterText(
        find.byKey(const Key('categoryNameField')),
        ' Gym ',
      );
      final icon = find.byKey(const Key('categoryIcon_fitness_center'));
      await tester.ensureVisible(icon);
      await tester.tap(icon);
      final color = find.byKey(const Key('categoryColor_#10AC84'));
      await tester.ensureVisible(color);
      await tester.tap(color);
      await tester.pumpAndSettle();
      expect(find.text('Gym'), findsOneWidget, reason: 'live preview');

      await tapSave(tester);

      final draft = result();
      expect(draft, isNotNull);
      expect(draft!.id, isNull);
      expect(draft.name, 'Gym');
      expect(draft.icon, 'fitness_center');
      expect(draft.colorHex, '#10AC84');
    });

    testWidgets('editing pre-fills and keeps the id', (tester) async {
      final result = await openSheet(
        tester,
        category: cat('food', name: 'Food'),
      );
      expect(find.text('Edit category'), findsOneWidget);
      expect(
        find.text('Built-in category · can be renamed and restyled'),
        findsOneWidget,
      );
      await tapSave(tester);
      expect(result()!.id, 'food');
      expect(result()!.name, 'Food');
    });
  });

  group('CategoryManagementScreen', () {
    late FakeCategoryRepository repo;

    setUp(() {
      repo = FakeCategoryRepository();
      repo.store['food'] = cat('food', name: 'Food');
      repo.store['custom'] = cat('custom', name: 'Coffee', isSystem: false);
      repo.store['old'] = cat('old', name: 'Old', isArchived: true);
    });

    Widget harness() => MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider(
        create: (_) => CategoryBloc(
          loadCategories: LoadCategoriesUseCase(repository: repo),
          saveCategory: SaveCategoryUseCase(
            repository: repo,
            idGenerator: () => 'n1',
          ),
          archiveCategory: ArchiveCategoryUseCase(repository: repo),
          deleteCategory: DeleteCategoryUseCase(repository: repo),
        ),
        child: const CategoryManagementScreen(),
      ),
    );

    testWidgets('lists available and archived categories', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Old'), findsOneWidget);
      expect(find.text('Built-in · Archived'), findsOneWidget);
    });

    testWidgets('system categories have no delete action', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category_menu_food')));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('archive from the menu moves the row and shows feedback', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category_menu_custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(find.text('"Coffee" archived'), findsOneWidget);
      expect(find.text('Custom · Archived'), findsOneWidget);
    });

    testWidgets('delete of an unused custom category asks first', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category_menu_custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete category?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Category deleted'), findsOneWidget);
    });

    testWidgets('FAB opens the new-category sheet', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsOneWidget);
      expect(find.byKey(const Key('categoryNameField')), findsOneWidget);
    });
  });
}
