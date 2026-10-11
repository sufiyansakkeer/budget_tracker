import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:monivo/features/dashboard/presentation/bloc/dashboard_state.dart';

import '../../../../integration/app_harness.dart';

/// UX-006: Home's "Coming up" read only bills due today or later, so an
/// overdue bill vanished from Home the day after it was due, and Home could
/// say "No bills due soon" while today's amount still set it aside.
void main() {
  late AppHarness app;
  final now = DateTime(2026, 8, 10, 9);
  final today = DateTime(2026, 8, 10);

  setUp(() async => app = await AppHarness.create());
  tearDown(() async => app.dispose());

  BillEntity bill(
    String id,
    DateTime due, {
    bool paid = false,
    String? budgetId,
  }) => BillEntity(
    id: id,
    title: 'Bill $id',
    amount: 500,
    currency: 'INR',
    category: BillCategory.electricity,
    dueDate: due,
    isPaid: paid,
    paidDate: paid ? due : null,
    budgetId: budgetId,
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  test('the repository returns unpaid bills due before today, the longest '
      'overdue first, and nothing due today or later', () async {
    for (final b in [
      bill('due-today', today),
      bill('tomorrow', DateTime(2026, 8, 11)),
      bill('yesterday', DateTime(2026, 8, 9)),
      bill('last-week', DateTime(2026, 8, 3)),
      bill('paid-late', DateTime(2026, 8, 1), paid: true),
    ]) {
      await app.billRepository.createBill(b);
    }

    final overdue = await app.billRepository.getOverdueBills(today: today);

    expect(overdue.map((b) => b.id), ['last-week', 'yesterday']);
  });

  test('Home lists overdue bills ahead of the upcoming ones', () async {
    await app.addBudget(
      id: 'aug',
      name: 'August',
      amount: 22000,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
    await app.billRepository.createBill(
      bill('soon', DateTime(2026, 8, 14), budgetId: 'aug'),
    );
    await app.billRepository.createBill(
      bill('late', DateTime(2026, 8, 7), budgetId: 'aug'),
    );

    final bloc = app.dashboardBloc(clock: () => now);
    addTearDown(bloc.close);
    bloc.add(const DashboardLoadData());
    final loaded =
        await bloc.stream.firstWhere((s) => s is DashboardLoaded)
            as DashboardLoaded;

    expect(loaded.upcomingBills.map((b) => b.id), ['late', 'soon']);
  });
}
