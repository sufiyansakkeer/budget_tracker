import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// How navigation icons are drawn.
enum NavIconRenderer {
  /// Rive artboards with a Material icon while loading / on failure.
  rive,

  /// Material icons only. Used by widget tests: the Rive runtime links a
  /// native library that is not available inside `flutter test`.
  material,
}

/// Selects the [NavIconRenderer] for the subtree.
///
/// Without an ancestor the app uses Rive, except under `flutter test` where
/// the Rive runtime's native library is unavailable and would throw
/// asynchronously; there the default is Material so any screen that happens
/// to include the bar can be pumped in a widget test.
class NavIconMode extends InheritedWidget {
  final NavIconRenderer renderer;

  const NavIconMode({super.key, required this.renderer, required super.child});

  static NavIconRenderer of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<NavIconMode>()
            ?.renderer ??
        defaultRenderer;
  }

  /// Renderer used when no [NavIconMode] ancestor exists.
  static NavIconRenderer get defaultRenderer =>
      _isFlutterTest ? NavIconRenderer.material : NavIconRenderer.rive;

  static final bool _isFlutterTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  bool updateShouldNotify(NavIconMode oldWidget) =>
      renderer != oldWidget.renderer;
}
