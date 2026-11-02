import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_failure.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/entities/tab_payment.dart';
import 'package:monivo/features/pay_later/domain/repository/pay_later_repository.dart';
import 'package:monivo/features/pay_later/domain/usecases/manage_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'package:monivo/features/pay_later/domain/validators/pay_later_tab_validator.dart';

import '../../../helpers/in_memory_database.dart';
import '../../../helpers/pay_later_memory_repository.dart';
import '../../../helpers/pay_later_fixtures.dart';

/// Notes whether each check and write ran inside a transaction.
class _TxMemoryRepository extends MemoryPayLaterRepository {
  int depth = 0;
  final List<(String, int)> events = [];

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    depth++;
    try {
      return await action();
    } finally {
      depth--;
    }
  }

  @override
  Future<PayLaterTab?> getTab(String id) {
    events.add(('getTab', depth));
    return super.getTab(id);
  }

  @override
  Future<bool> tabHasActivity(String tabId) {
    events.add(('tabHasActivity', depth));
    return super.tabHasActivity(tabId);
  }

  @override
  Future<void> updateTab(PayLaterTab tab) {
    events.add(('updateTab', depth));
    return super.updateTab(tab);
  }

  @override
  Future<void> deleteTab(String id) {
    events.add(('deleteTab', depth));
    return super.deleteTab(id);
  }
}

void main() {
  final today = DateTime(2026, 11, 2, 10);

  group('check-then-write is one transaction (T5)', () {
    late _TxMemoryRepository repo;
    late ManageTabUseCase manage;

    setUp(() {
      repo = _TxMemoryRepository()..addTab(payLaterTab('t1'));
      manage = ManageTabUseCase(repository: repo, clock: () => today);
    });

    void expectAllInside() {
      expect(repo.events, isNotEmpty);
      expect(
        repo.events.every((e) => e.$2 > 0),
        isTrue,
        reason: '${repo.events}',
      );
    }

    test('update', () async {
      final result = await manage.update(
        payLaterTab('t1', name: 'Renamed', currency: 'INR'),
      );
      expect(result, isA<PayLaterSuccess<PayLaterTab>>());
      expectAllInside();
    });

    test('archive', () async {
      expect(await manage.archive('t1'), isA<PayLaterSuccess<PayLaterTab>>());
      expectAllInside();
    });

    test('delete', () async {
      expect(await manage.delete('t1'), isA<PayLaterSuccess<void>>());
      expectAllInside();
      expect(repo.events.map((e) => e.$1), contains('deleteTab'));
    });
  });

  group('PayLaterTabValidator', () {
    String? check(PayLaterTab t, {bool isCreate = true}) =>
        PayLaterTabValidator.validate(t, today: today, isCreate: isCreate);

    test('accepts a valid tab', () {
      expect(check(payLaterTab('t')), isNull);
    });

    test('name is trimmed and 1 to 100 characters', () {
      expect(check(payLaterTab('t', name: '   ')), isNotNull);
      expect(check(payLaterTab('t', name: 'a' * 101)), isNotNull);
      expect(check(payLaterTab('t', name: ' ${'a' * 100} ')), isNull);
    });

    test('currency must not be empty', () {
      expect(check(payLaterTab('t', currency: '')), isNotNull);
    });

    test('EveryDays is 1 to 365', () {
      EveryDays every(int d) => EveryDays(days: d, anchor: today);
      expect(check(payLaterTab('t', rhythm: every(0))), isNotNull);
      expect(check(payLaterTab('t', rhythm: every(366))), isNotNull);
      expect(check(payLaterTab('t', rhythm: every(1))), isNull);
      expect(check(payLaterTab('t', rhythm: every(365))), isNull);
    });

    test('MonthlyDay is 1 to 31', () {
      expect(
        check(payLaterTab('t', rhythm: const MonthlyDay(day: 0))),
        isNotNull,
      );
      expect(
        check(payLaterTab('t', rhythm: const MonthlyDay(day: 32))),
        isNotNull,
      );
      expect(
        check(payLaterTab('t', rhythm: const MonthlyDay(day: 31))),
        isNull,
      );
    });

    test('ManualDate may not be in the past on create, only', () {
      final past = payLaterTab(
        't',
        rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 1)),
      );
      final sameDay = payLaterTab(
        't',
        rhythm: ManualDate(nextSettleDate: DateTime(2026, 11, 2)),
      );
      expect(check(past), isNotNull);
      expect(check(past, isCreate: false), isNull);
      expect(check(sameDay), isNull);
    });

    test('reminder offset is 0 to 7', () {
      expect(
        check(payLaterTab('t').copyWith(reminderOffsetDays: -1)),
        isNotNull,
      );
      expect(
        check(payLaterTab('t').copyWith(reminderOffsetDays: 8)),
        isNotNull,
      );
      expect(check(payLaterTab('t').copyWith(reminderOffsetDays: 7)), isNull);
    });
  });

  group('ManageTabUseCase and ReconcileTabUseCase', () {
    late AppDatabase db;
    late PayLaterRepository repo;
    late ManageTabUseCase manage;

    PayLaterErrorType? errorOf<T>(PayLaterResult<T> r) =>
        r is PayLaterError<T> ? r.failure.type : null;

    setUp(() async {
      db = await createInMemoryDatabase();
      repo = PayLaterRepositoryImpl(
        localDataSource: PayLaterLocalDataSourceImpl(database: db),
      );
      manage = ManageTabUseCase(repository: repo, clock: () => today);
      await seedPayLaterBudget(db);
    });

    tearDown(() => db.close());

    Future<void> addPurchase(String tabId, String id, double amount) async {
      await addPayLaterExpense(db, payLaterExpense(id, amount: amount));
      await repo.linkExpense(expenseId: id, tabId: tabId);
    }

    Future<void> pay(String tabId, String id, double amount) =>
        repo.createPayment(
          TabPayment(
            id: id,
            tabId: tabId,
            amount: amount,
            paidDate: DateTime(2026, 11, 2),
            createdAt: payLaterStamp,
            updatedAt: payLaterStamp,
          ),
        );

    test('create trims the name and stores the tab', () async {
      final r = await manage.create(payLaterTab('t1', name: '  Shop  '));
      expect(r, isA<PayLaterSuccess<PayLaterTab>>());
      expect((await repo.getTab('t1'))!.name, 'Shop');
    });

    test('create rejects invalid input without writing', () async {
      final r = await manage.create(payLaterTab('t1', name: ''));
      expect(errorOf(r), PayLaterErrorType.invalidInput);
      expect(await repo.getTab('t1'), isNull);
    });

    test('update of a missing tab is notFound', () async {
      expect(
        errorOf(await manage.update(payLaterTab('nope'))),
        PayLaterErrorType.notFound,
      );
    });

    test('currency locked once used', () async {
      await manage.create(payLaterTab('t1'));
      final free = await manage.update(
        payLaterTab('t1', currency: 'USD', name: 'Renamed'),
      );
      expect(free, isA<PayLaterSuccess<PayLaterTab>>());

      await addPurchase('t1', 'e1', 5);
      final locked = await manage.update(payLaterTab('t1', currency: 'OMR'));
      expect(errorOf(locked), PayLaterErrorType.inUse);
      expect((await repo.getTab('t1'))!.currency, 'USD');

      // Same currency still editable.
      final rename = await manage.update(
        payLaterTab('t1', currency: 'USD', name: 'Again'),
      );
      expect(rename, isA<PayLaterSuccess<PayLaterTab>>());
    });

    test('archive refused while the tab owes', () async {
      await manage.create(payLaterTab('t1'));
      await addPurchase('t1', 'e1', 5);
      expect(errorOf(await manage.archive('t1')), PayLaterErrorType.hasBalance);
      expect((await repo.getTab('t1'))!.isArchived, isFalse);
    });

    test('archive refused while the tab holds credit', () async {
      await manage.create(payLaterTab('t1'));
      await pay('t1', 'p1', 5);
      expect(errorOf(await manage.archive('t1')), PayLaterErrorType.hasBalance);
    });

    test('archive and unarchive a settled tab', () async {
      await manage.create(payLaterTab('t1'));
      await addPurchase('t1', 'e1', 5);
      await pay('t1', 'p1', 5);
      await repo.transaction(() => ReconcileTabUseCase(repository: repo)('t1'));

      expect(await manage.archive('t1'), isA<PayLaterSuccess<PayLaterTab>>());
      expect((await repo.getTab('t1'))!.isArchived, isTrue);
      expect(await manage.unarchive('t1'), isA<PayLaterSuccess<PayLaterTab>>());
      expect((await repo.getTab('t1'))!.isArchived, isFalse);
    });

    test('update cannot archive an owing tab', () async {
      await manage.create(payLaterTab('t1'));
      await addPurchase('t1', 'e1', 5);
      final r = await manage.update(
        payLaterTab('t1', name: 'Renamed').copyWith(isArchived: true),
      );
      expect(r, isA<PayLaterSuccess<PayLaterTab>>());
      final stored = (await repo.getTab('t1'))!;
      expect(stored.isArchived, isFalse);
      expect(stored.name, 'Renamed');
    });

    test('update cannot unarchive an archived tab', () async {
      await manage.create(payLaterTab('t1'));
      await manage.archive('t1');
      await manage.update(payLaterTab('t1', name: 'Renamed'));
      final stored = (await repo.getTab('t1'))!;
      expect(stored.isArchived, isTrue);
      expect(stored.name, 'Renamed');
    });

    test('archive and unarchive of a missing tab are notFound', () async {
      expect(errorOf(await manage.archive('x')), PayLaterErrorType.notFound);
      expect(errorOf(await manage.unarchive('x')), PayLaterErrorType.notFound);
    });

    test('delete refused for a used tab, allowed for an empty one', () async {
      await manage.create(payLaterTab('t1'));
      await manage.create(payLaterTab('t2'));
      await addPurchase('t1', 'e1', 5);

      expect(errorOf(await manage.delete('t1')), PayLaterErrorType.inUse);
      expect(await repo.getTab('t1'), isNotNull);

      expect(await manage.delete('t2'), isA<PayLaterSuccess<void>>());
      expect(await repo.getTab('t2'), isNull);
      expect(errorOf(await manage.delete('t2')), PayLaterErrorType.notFound);
    });

    group('manual date anchor roll-over', () {
      final oldDate = DateTime(2026, 10, 20);
      final newDate = DateTime(2026, 12, 1);

      Future<ManualDate> saveAfter(
        ManualDate stored,
        ManualDate incoming,
      ) async {
        // Seeded directly: create refuses a date in the past.
        await repo.createTab(payLaterTab('m', rhythm: stored));
        final result = await manage.update(payLaterTab('m', rhythm: incoming));
        expect(result, isA<PayLaterSuccess<PayLaterTab>>());
        return (await repo.getTab('m'))!.rhythm as ManualDate;
      }

      test(
        'a passed date and a new date roll the anchor to the old date',
        () async {
          final saved = await saveAfter(
            ManualDate(nextSettleDate: oldDate, anchor: DateTime(2026, 9, 20)),
            ManualDate(nextSettleDate: newDate),
          );
          expect(saved.nextSettleDate, newDate);
          expect(saved.anchor, oldDate);
        },
      );

      test(
        'a date not yet passed changed to another keeps the anchor',
        () async {
          final anchor = DateTime(2026, 10, 1);
          final saved = await saveAfter(
            ManualDate(nextSettleDate: DateTime(2026, 11, 2), anchor: anchor),
            ManualDate(nextSettleDate: newDate, anchor: anchor),
          );
          expect(saved.nextSettleDate, newDate);
          expect(saved.anchor, anchor);
        },
      );

      test(
        'a passed date re-saved with the same date keeps the anchor',
        () async {
          final anchor = DateTime(2026, 9, 20);
          final saved = await saveAfter(
            ManualDate(nextSettleDate: oldDate, anchor: anchor),
            ManualDate(nextSettleDate: oldDate, anchor: anchor),
          );
          expect(saved.nextSettleDate, oldDate);
          expect(saved.anchor, anchor);
        },
      );
    });
  });
}
