/// Where an animated navigation icon lives inside a `.riv` file.
///
/// Pure description, no Rive types, so navigation configuration can be
/// declared as `const` and tested without the runtime.
class RiveIconSpec {
  /// Asset bundle path, e.g. `assets/rive/nav_icons.riv`.
  final String asset;

  /// Artboard name inside the file.
  final String artboard;

  /// State machine on that artboard.
  final String stateMachine;

  /// Name of the boolean input that plays the "active" animation.
  final String input;

  /// Visual scale applied to the artwork so glyphs of different weight
  /// (filled vs. outlined) sit at the same optical size. 1.0 = as authored.
  final double scale;

  const RiveIconSpec({
    required this.asset,
    required this.artboard,
    required this.stateMachine,
    required this.input,
    this.scale = 1.0,
  });
}
