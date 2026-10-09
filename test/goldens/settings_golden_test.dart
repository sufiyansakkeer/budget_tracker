@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/features/categories/domain/usecases/archive_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/load_categories_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/save_category_usecase.dart';
import 'package:monivo/features/categories/presentation/bloc/category_bloc.dart';
import 'package:monivo/features/categories/presentation/pages/category_management_screen.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_bloc.dart';
import 'package:monivo/features/settings/presentation/bloc/theme/theme_state.dart';
import 'package:monivo/features/settings/presentation/pages/palette_selection_screen.dart';

import '../features/categories/domain/usecases/category_usecases_test.dart'
    show FakeCategoryRepository;
import '../features/settings/presentation/pages/settings_test_harness.dart';
import 'golden_harness.dart';

void main() {
  setUp(setUpSettingsScreen);
  tearDown(() => getIt.reset());

  testWidgets('settings', (tester) async {
    final settings = StaticSettingsBloc(
      loadedSettings,
      integrityService: FakeIntegrityService(),
    );
    final theme = StaticThemeBloc(const ThemeState());
    addTearDown(settings.close);
    addTearDown(theme.close);
    await expectGoldenMatrix(
      tester,
      'settings',
      settingsScreen(settings: settings, theme: theme),
      size: const Size(360, 2500),
    );
  }, skip: goldenSkip);

  testWidgets('palettes', (tester) async {
    final theme = StaticThemeBloc(
      const ThemeState(palette: ColorPalette.defaultPalette),
    );
    addTearDown(theme.close);
    await expectGoldenMatrix(
      tester,
      'palettes',
      BlocProvider<ThemeBloc>.value(
        value: theme,
        child: const PaletteSelectionScreen(),
      ),
      size: const Size(360, 1300),
    );
  }, skip: goldenSkip);

  testWidgets('categories', (tester) async {
    final repo = FakeCategoryRepository();
    for (final c in defaultCategories) {
      repo.store[c.id] = c;
    }
    repo.store['coffee'] = const ExpenseCategory(
      id: 'coffee',
      name: 'Coffee',
      icon: 'local_cafe',
      colorHex: '#795548',
      isSystem: false,
    );
    repo.store['gifts'] = const ExpenseCategory(
      id: 'gifts',
      name: 'Gifts',
      icon: 'card_giftcard',
      colorHex: '#F368E0',
      isSystem: false,
      isArchived: true,
    );
    await expectGoldenMatrix(
      tester,
      'categories',
      BlocProvider(
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
      size: const Size(360, 1400),
    );
  }, skip: goldenSkip);
}
