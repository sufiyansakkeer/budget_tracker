import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';

void main() {
  test('payLater bus is named and emits on notifyChanged', () async {
    expect(RefreshBuses.payLater.name, 'payLater');
    final emitted = expectLater(RefreshBuses.payLater.changes, emits(null));
    RefreshBuses.payLater.notifyChanged();
    await emitted;
  });
}
