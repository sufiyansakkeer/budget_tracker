import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/categories/domain/usecases/archive_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/load_categories_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/save_category_usecase.dart';
import 'package:monivo/features/categories/presentation/bloc/category_bloc.dart';
import 'package:monivo/features/categories/presentation/bloc/category_event.dart';
import 'package:monivo/features/categories/presentation/bloc/category_state.dart';

import '../../domain/usecases/category_usecases_test.dart'
    show FakeCategoryRepository, cat;

void main() {
  late FakeCategoryRepository repo;

  CategoryBloc build() => CategoryBloc(
    loadCategories: LoadCategoriesUseCase(repository: repo),
    saveCategory: SaveCategoryUseCase(
      repository: repo,
      idGenerator: () => 'n1',
    ),
    archiveCategory: ArchiveCategoryUseCase(repository: repo),
    deleteCategory: DeleteCategoryUseCase(repository: repo),
  );

  setUp(() {
    repo = FakeCategoryRepository();
    repo.store['food'] = cat('food', name: 'Food');
    repo.store['custom'] = cat('custom', name: 'Coffee', isSystem: false);
  });

  blocTest<CategoryBloc, CategoryState>(
    'loads categories: loading → loaded',
    build: build,
    act: (b) => b.add(const CategoryLoad()),
    expect: () => [
      const CategoryState(status: CategoryBlocStatus.loading),
      isA<CategoryState>()
          .having((s) => s.status, 'status', CategoryBlocStatus.loaded)
          .having((s) => s.categories.length, 'count', 2),
    ],
  );

  blocTest<CategoryBloc, CategoryState>(
    'save adds the category, reloads and reports a message',
    build: build,
    seed: () => CategoryState(
      status: CategoryBlocStatus.loaded,
      categories: repo.store.values.toList(),
    ),
    act: (b) => b.add(
      const CategorySave(
        name: 'Gym',
        icon: 'fitness_center',
        colorHex: '#10AC84',
      ),
    ),
    expect: () => [
      isA<CategoryState>().having(
        (s) => s.status,
        'status',
        CategoryBlocStatus.saving,
      ),
      isA<CategoryState>()
          .having((s) => s.status, 'status', CategoryBlocStatus.loaded)
          .having((s) => s.categories.length, 'count', 3)
          .having((s) => s.message, 'message', '"Gym" added'),
    ],
  );

  blocTest<CategoryBloc, CategoryState>(
    'save failure keeps the list and surfaces the error',
    build: build,
    seed: () => CategoryState(
      status: CategoryBlocStatus.loaded,
      categories: repo.store.values.toList(),
    ),
    act: (b) => b.add(
      const CategorySave(name: 'food', icon: 'restaurant', colorHex: '#FF0000'),
    ),
    expect: () => [
      isA<CategoryState>().having(
        (s) => s.status,
        'status',
        CategoryBlocStatus.saving,
      ),
      isA<CategoryState>()
          .having((s) => s.status, 'status', CategoryBlocStatus.loaded)
          .having((s) => s.categories.length, 'count', 2)
          .having((s) => s.errorMessage, 'error', contains('already exists')),
    ],
  );

  blocTest<CategoryBloc, CategoryState>(
    'archive moves the category to the archived group',
    build: build,
    act: (b) => b.add(const CategorySetArchived('custom', archived: true)),
    verify: (b) {
      expect(b.state.archived.map((c) => c.id), ['custom']);
      expect(b.state.active.map((c) => c.id), ['food']);
      expect(b.state.message, '"Coffee" archived');
    },
  );

  blocTest<CategoryBloc, CategoryState>(
    'delete of a system category is refused with a message',
    build: build,
    act: (b) => b.add(const CategoryDelete('food')),
    verify: (b) {
      expect(repo.store.containsKey('food'), isTrue);
      expect(b.state.errorMessage, contains('Built-in'));
    },
  );

  test('successful mutations notify the expenses refresh bus', () async {
    final bloc = build();
    var notified = 0;
    final sub = RefreshBuses.expenses.changes.listen((_) => notified++);
    bloc.add(const CategoryDelete('custom'));
    await bloc.stream.firstWhere((s) => s.status == CategoryBlocStatus.loaded);
    await Future<void>.delayed(Duration.zero);
    expect(notified, 1);
    await sub.cancel();
    unawaited(bloc.close());
  });

  blocTest<CategoryBloc, CategoryState>(
    'clear message wipes one-shot feedback',
    build: build,
    seed: () => const CategoryState(
      status: CategoryBlocStatus.loaded,
      message: 'hi',
      errorMessage: 'bad',
    ),
    act: (b) => b.add(const CategoryClearMessage()),
    expect: () => [const CategoryState(status: CategoryBlocStatus.loaded)],
  );
}
