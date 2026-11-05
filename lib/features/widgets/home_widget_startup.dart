/// Start-up order of the home-widget platform calls, kept apart from
/// `main.dart` so it can be tested without the whole app.
library;

/// The three home-widget platform calls made before the first frame, run
/// side by side instead of one after another (each crosses a platform
/// channel, so in sequence they held the splash for three round trips).
///
/// [readLaunch] (was the app opened from the widget?) needs nothing else.
/// [registerCallbacks] stores its handle in the App Group on iOS, so it
/// still runs only after [configure]. Completes when all have finished; the
/// widget data update must start after it, since saving needs the App Group.
/// Each step handles its own errors.
Future<void> prepareHomeWidget({
  required Future<void> Function() configure,
  required Future<void> Function() readLaunch,
  required Future<void> Function() registerCallbacks,
}) async {
  await Future.wait([
    configure().then((_) => registerCallbacks()),
    readLaunch(),
  ]);
}
