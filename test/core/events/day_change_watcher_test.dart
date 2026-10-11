import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/day_change_watcher.dart';
import 'package:monivo/core/events/refresh_bus.dart';

/// UX-001: the watcher tells the day bus about a new calendar day exactly
/// once, and stays quiet for checks on the same day.
void main() {
  late RefreshBus bus;
  late DateTime now;
  late int notified;

  setUp(() {
    bus = RefreshBus('day-test');
    now = DateTime(2026, 10, 9, 22, 30);
    notified = 0;
    bus.changes.listen((_) => notified++);
  });

  tearDown(() => bus.dispose());

  test('the same day is not a change, however late it gets', () async {
    final watcher = DayChangeWatcher(clock: () => now, bus: bus);

    now = DateTime(2026, 10, 9, 23, 59, 59);
    expect(watcher.check(), isFalse);
    await pumpEventQueue();
    expect(notified, 0);
  });

  test(
    'crossing midnight notifies once; later checks that day do not',
    () async {
      final watcher = DayChangeWatcher(clock: () => now, bus: bus);

      now = DateTime(2026, 10, 10, 7, 15);
      expect(watcher.check(), isTrue);
      expect(watcher.check(), isFalse);
      now = DateTime(2026, 10, 10, 21);
      expect(watcher.check(), isFalse);
      await pumpEventQueue();
      expect(notified, 1);
    },
  );

  test('a resume several days later is one change', () async {
    final watcher = DayChangeWatcher(clock: () => now, bus: bus);

    now = DateTime(2026, 10, 13, 8);
    expect(watcher.check(), isTrue);
    await pumpEventQueue();
    expect(notified, 1);
  });

  test('a clock set back to an earlier day is also a change', () async {
    final watcher = DayChangeWatcher(clock: () => now, bus: bus);

    now = DateTime(2026, 10, 8, 12);
    expect(watcher.check(), isTrue);
    await pumpEventQueue();
    expect(notified, 1);
  });
}
