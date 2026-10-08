import 'package:flutter/material.dart';

import 'app_colors_extension.dart';

/// The meaning a status carries, independent of which palette is active.
///
/// Every status in the app (a budget's health, today's safe spending, a
/// bill) maps to one tone, and the tone decides its colours. Amounts stay in
/// ink; colour marks the state next to them, never the figure itself.
///
/// * [positive]: on track, set aside, paid.
/// * [caution]: slow down; recoverable (over today's amount, at risk,
///   near a limit, due soon).
/// * [critical]: money is already gone (over budget, bills exceed what is
///   left, overdue).
/// * [info]: neutral facts that still deserve a hue.
/// * [neutral]: not started, ended, not set.
enum AppTone { positive, caution, critical, info, neutral }

/// The three colours a tone draws with, all from the contrast-checked
/// tokens: [accent] for an icon or a bar on a card, [container] for a chip or
/// notice fill, and [onContainer] for text and icons on that fill.
@immutable
class ToneColors {
  final Color accent;
  final Color container;
  final Color onContainer;

  const ToneColors({
    required this.accent,
    required this.container,
    required this.onContainer,
  });
}

/// Resolves an [AppTone] against the current tokens.
extension AppToneColors on AppColorTokens {
  ToneColors tone(AppTone tone) => switch (tone) {
    AppTone.positive => ToneColors(
      accent: success,
      container: successContainer,
      onContainer: onSuccessContainer,
    ),
    AppTone.caution => ToneColors(
      accent: warning,
      container: warningContainer,
      onContainer: onWarningContainer,
    ),
    AppTone.critical => ToneColors(
      accent: error,
      container: errorContainer,
      onContainer: onErrorContainer,
    ),
    AppTone.info => ToneColors(
      accent: info,
      container: infoContainer,
      onContainer: onInfoContainer,
    ),
    // textSecondary is held to 4.5:1 on surfaceContainerHigh, so it is
    // already legible on that fill.
    AppTone.neutral => ToneColors(
      accent: textSecondary,
      container: surfaceContainerHigh,
      onContainer: textSecondary,
    ),
  };
}

/// Shorthand: `context.tone(AppTone.caution)`.
extension AppToneContext on BuildContext {
  ToneColors tone(AppTone tone) => appColors.tone(tone);
}
