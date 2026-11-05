import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/widgets/home_widget_startup.dart';

// UX-105: the three home-widget platform calls before the first frame ran
// one after another; the launch check now overlaps the App Group setup.
void main() {
  test('reads the launch while the App Group is still being set, and '
      'registers the callback only after it', () async {
    final log = <String>[];
    final configure = Completer<void>();
    final launch = Completer<void>();

    var done = false;
    final ready = prepareHomeWidget(
      configure: () {
        log.add('configure');
        return configure.future;
      },
      readLaunch: () {
        log.add('launch');
        return launch.future;
      },
      registerCallbacks: () async => log.add('register'),
    ).then((_) => done = true);

    await pumpEventQueue();
    // Both started at once; the callback waits for the App Group (iOS
    // stores its handle there).
    expect(log, ['configure', 'launch']);

    configure.complete();
    await pumpEventQueue();
    expect(log, ['configure', 'launch', 'register']);
    expect(done, isFalse, reason: 'the launch route is still unknown');

    launch.complete();
    await ready;
    expect(done, isTrue);
  });
}
