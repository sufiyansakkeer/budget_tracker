import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/features/pay_later/presentation/pay_later_startup.dart';

import '../../../helpers/pay_later_fakes.dart';

/// Reconciling fails, as on a database that can't be written.
class _FailingReconcile extends FakeReconcileTabUseCase {
  @override
  Future<void> all() async {
    calls.add('all');
    throw StateError('disk I/O');
  }
}

void main() {
  late RefreshBus bus;
  late int notified;

  setUp(() {
    bus = RefreshBus('test');
    notified = 0;
    bus.changes.listen((_) => notified++);
  });

  tearDown(() => bus.dispose());

  test('reconciles every tab, then tells open screens to reload', () async {
    final reconcile = FakeReconcileTabUseCase();

    await reconcilePayLaterTabsOnStartup(reconcile, bus: bus);
    await pumpEventQueue();

    expect(reconcile.calls, ['all']);
    expect(notified, 1);
  });

  test('a failed reconcile is not fatal and changes nothing', () async {
    final reconcile = _FailingReconcile();

    await reconcilePayLaterTabsOnStartup(reconcile, bus: bus);
    await pumpEventQueue();

    expect(reconcile.calls, ['all']);
    expect(notified, 0);
  });

  test('notifies the app-wide pay later bus by default', () async {
    var appNotified = 0;
    final sub = RefreshBuses.payLater.changes.listen((_) => appNotified++);
    addTearDown(sub.cancel);

    await reconcilePayLaterTabsOnStartup(FakeReconcileTabUseCase());
    await pumpEventQueue();

    expect(appNotified, 1);
  });
}
