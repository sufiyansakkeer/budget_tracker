import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/categories/domain/entities/category_failure.dart';
import 'package:monivo/features/categories/domain/repository/category_repository.dart';
import 'package:monivo/features/categories/domain/usecases/archive_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/delete_category_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/load_categories_usecase.dart';
import 'package:monivo/features/categories/domain/usecases/save_category_usecase.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';

class FakeCategoryRepository implements CategoryRepository {
  final Map<String, ExpenseCategory> store = {};
  final Map<String, int> usage = {};
  bool failNext = false;

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw Exception('boom');
    }
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    _maybeFail();
    return store.values.toList();
  }

  @override
  Future<ExpenseCategory?> getCategoryById(String id) async => store[id];

  @override
  Future<void> createCategory(ExpenseCategory category) async {
    _maybeFail();
    store[category.id] = category;
  }

  @override
  Future<void> updateCategory(ExpenseCategory category) async {
    _maybeFail();
    store[category.id] = category;
  }

  @override
  Future<void> deleteCategory(String id) async => store.remove(id);

  @override
  Future<int> countExpenses(String categoryId) async => usage[categoryId] ?? 0;
}

ExpenseCategory cat(
  String id, {
  String? name,
  bool isSystem = true,
  bool isArchived = false,
}) => ExpenseCategory(
  id: id,
  name: name ?? id,
  icon: 'restaurant',
  colorHex: '#FF6B6B',
  isSystem: isSystem,
  isArchived: isArchived,
);

void main() {
  late FakeCategoryRepository repo;

  setUp(() {
    repo = FakeCategoryRepository();
    repo.store['food'] = cat('food', name: 'Food');
    repo.store['old'] = cat('old', name: 'Old', isArchived: true);
    repo.store['custom'] = cat('custom', name: 'Coffee', isSystem: false);
  });

  group('LoadCategoriesUseCase', () {
    test('active first, alphabetical, archived last', () async {
      final result = await LoadCategoriesUseCase(repository: repo)();
      final list = (result as CategorySuccess<List<ExpenseCategory>>).data;
      expect(list.map((c) => c.id).toList(), ['custom', 'food', 'old']);
    });

    test('wraps repository errors', () async {
      repo.failNext = true;
      final result = await LoadCategoriesUseCase(repository: repo)();
      expect(
        (result as CategoryError).failure.type,
        CategoryErrorType.databaseFailure,
      );
    });
  });

  group('SaveCategoryUseCase', () {
    late SaveCategoryUseCase save;
    setUp(() {
      save = SaveCategoryUseCase(repository: repo, idGenerator: () => 'new-id');
    });

    test('creates a custom category with a trimmed name', () async {
      final result = await save(
        name: '  Gym ',
        icon: 'fitness_center',
        colorHex: '#10ac84',
      );
      final created = (result as CategorySuccess<ExpenseCategory>).data;
      expect(created.id, 'new-id');
      expect(created.name, 'Gym');
      expect(created.colorHex, '#10AC84');
      expect(created.isSystem, isFalse);
      expect(repo.store['new-id'], created);
    });

    test('rejects invalid input before touching the repository', () async {
      final result = await save(
        name: '',
        icon: 'restaurant',
        colorHex: '#FF0000',
      );
      expect(
        (result as CategoryError).failure.type,
        CategoryErrorType.invalidInput,
      );
      expect(repo.store.length, 3);
    });

    test('rejects duplicate names ignoring case', () async {
      final result = await save(
        name: 'FOOD',
        icon: 'restaurant',
        colorHex: '#FF0000',
      );
      expect(
        (result as CategoryError).failure.type,
        CategoryErrorType.duplicateName,
      );
    });

    test('updates keep the system flag and allow the same name', () async {
      final result = await save(
        id: 'food',
        name: 'Food',
        icon: 'fastfood',
        colorHex: '#EE5253',
      );
      final updated = (result as CategorySuccess<ExpenseCategory>).data;
      expect(updated.isSystem, isTrue);
      expect(updated.icon, 'fastfood');
      expect(repo.store['food']!.icon, 'fastfood');
    });

    test('update of a missing id is notFound', () async {
      final result = await save(
        id: 'ghost',
        name: 'Ghost',
        icon: 'pets',
        colorHex: '#000000',
      );
      expect(
        (result as CategoryError).failure.type,
        CategoryErrorType.notFound,
      );
    });
  });

  group('ArchiveCategoryUseCase', () {
    test('archives and restores', () async {
      final archive = ArchiveCategoryUseCase(repository: repo);
      var result = await archive('custom', archived: true);
      expect(
        (result as CategorySuccess<ExpenseCategory>).data.isArchived,
        isTrue,
      );
      result = await archive('custom', archived: false);
      expect(
        (result as CategorySuccess<ExpenseCategory>).data.isArchived,
        isFalse,
      );
    });

    test('refuses to archive the last available category', () async {
      repo.store.remove('custom');
      final result = await ArchiveCategoryUseCase(repository: repo)(
        'food',
        archived: true,
      );
      expect(
        (result as CategoryError).failure.type,
        CategoryErrorType.lastActive,
      );
      expect(repo.store['food']!.isArchived, isFalse);
    });
  });

  group('DeleteCategoryUseCase', () {
    test('deletes an unused custom category', () async {
      final result = await DeleteCategoryUseCase(repository: repo)('custom');
      expect(result, isA<CategorySuccess<void>>());
      expect(repo.store.containsKey('custom'), isFalse);
    });

    test('never deletes system categories', () async {
      final result = await DeleteCategoryUseCase(repository: repo)('food');
      expect(
        (result as CategoryError).failure.type,
        CategoryErrorType.systemCategory,
      );
      expect(repo.store.containsKey('food'), isTrue);
    });

    test('refuses when expenses reference it and says how many', () async {
      repo.usage['custom'] = 3;
      final result = await DeleteCategoryUseCase(repository: repo)('custom');
      final failure = (result as CategoryError).failure;
      expect(failure.type, CategoryErrorType.inUse);
      expect(failure.message, contains('3 expenses'));
      expect(repo.store.containsKey('custom'), isTrue);
    });
  });
}
