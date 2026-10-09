import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';

/// Shared setup for golden (screenshot) tests.
///
/// Goldens are only compared on macOS: font rasterisation differs on the
/// Linux CI runners, so a golden made on a Mac would fail there for reasons
/// that have nothing to do with the UI. Every golden test passes
/// [goldenSkip] as its `skip:` and carries the `golden` tag.
///
/// The real fonts are loaded (Manrope and the Omani rial sign from the app's
/// assets, Material Icons from the Flutter SDK) so the images show the actual design instead of
/// the test font's boxes.
final bool goldenSkip = !Platform.isMacOS;

bool _fontsLoaded = false;

Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  final manrope = FontLoader('Manrope');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File(
      'assets/fonts/manrope/Manrope-$weight.ttf',
    ).readAsBytesSync();
    manrope.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await manrope.load();

  // The Omani rial sign (U+20C4), the theme's fallback after Manrope.
  final rial = FontLoader('MonivoOmaniRial');
  for (final weight in ['Light', 'Medium', 'Bold']) {
    final bytes = File(
      'assets/fonts/omani_rial/MonivoOmaniRial-$weight.ttf',
    ).readAsBytesSync();
    rial.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await rial.load();

  final icons = _materialIconsFont();
  if (icons != null) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
  _fontsLoaded = true;
}

/// MaterialIcons-Regular.otf from the Flutter SDK that is running the test.
File? _materialIconsFont() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    final candidate = File(
      '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

/// A phone-sized frame: [width] logical pixels wide, [textScale] applied,
/// in the light or dark theme of the default palette.
Widget goldenFrame({
  required Widget child,
  required Brightness brightness,
  double textScale = 1.0,
}) {
  final theme = brightness == Brightness.light
      ? AppTheme.lightTheme
      : AppTheme.darkTheme;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child,
      ),
    ),
  );
}

/// Pumps [child] in light and dark at 1.0 and 2.0 text scale and compares
/// each against `goldens/<name>.<theme>.<scale>x.png`.
Future<void> expectGoldenMatrix(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(360, 780),
}) async {
  await loadAppFonts();
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  addTearDown(tester.view.reset);
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        goldenFrame(child: child, brightness: brightness, textScale: scale),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/$name.${brightness.name}.${scale.toStringAsFixed(0)}x.png',
        ),
      );
    }
  }
}
