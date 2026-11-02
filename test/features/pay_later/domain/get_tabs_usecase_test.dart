import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/pay_later/domain/usecases/get_tabs_usecase.dart';

import '../../../helpers/in_memory_database.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// A repository whose tab list can't be read.
class _BrokenRepository implements PayLaterRepository {
  @override
  Future<List<PayLaterTab>> getTabs() async => throw Exception('disk I/O');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late PayLaterRepositoryImpl repo;

  setUp(() async {
    db = await createInMemoryDatabase();
    repo = PayLaterRepositoryImpl(
      localDataSource: PayLaterLocalDataSourceImpl(database: db),
    );
  });

  tearDown(() => db.close());

  test('returns every tab, archived included (the caller filters)', () async {
    await repo.createTab(payLaterTab('t1', name: 'Cafeteria'));
    await repo.createTab(
      payLaterTab('t2', name: 'Old shop').copyWith(isArchived: true),
    );

    final result = await GetTabsUseCase(repository: repo)();

    expect(result, isA<PayLaterSuccess<List<PayLaterTab>>>());
    final tabs = (result as PayLaterSuccess<List<PayLaterTab>>).data;
    expect(tabs.map((t) => t.id).toSet(), {'t1', 't2'});
  });

  test('a read failure is a databaseFailure, not an empty list', () async {
    final result = await GetTabsUseCase(repository: _BrokenRepository())();

    expect(result, isA<PayLaterError<List<PayLaterTab>>>());
    final failure = (result as PayLaterError<List<PayLaterTab>>).failure;
    expect(failure.type, PayLaterErrorType.databaseFailure);
  });
}
