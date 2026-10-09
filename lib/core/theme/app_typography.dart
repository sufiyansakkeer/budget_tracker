import 'package:flutter/material.dart';

/// Monivo's typography: one bundled family (Manrope) for text and numbers.
///
/// Text roles are the Material [TextTheme] built in `AppTheme`. Money has its
/// own roles here, because amounts need things prose must not have:
/// tabular figures (every digit the same width, so an amount does not shift
/// when it changes and columns line up), tighter tracking at large sizes and
/// weights chosen for numerals.
///
/// | Role             | Size / line | Weight | Used for                                   |
/// | ---------------- | ----------- | ------ | ------------------------------------------ |
/// | [moneyHero]      | 48 / 50     | 800    | Today's Safe Spending only                 |
/// | [moneyDisplay]   | 32 / 36     | 800    | Report total, budget remaining, detail amount |
/// | [moneyTitle]     | 20 / 24     | 700    | Section totals, Free to spend, summaries   |
/// | [moneyBody]      | 15 / 20     | 700    | Every list amount, right-aligned           |
/// | [moneyCaption]   | 12 / 16     | 600    | Figures inside captions and chips          |
///
/// [eyebrow] is the small label above a figure or section ("Spent today").
///
/// Colours are left unset: a role inherits the ambient text colour, and the
/// widget that draws it decides whether the figure is ink or a status tone.
/// Access with `context.appTypography`.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  /// The bundled family declared in pubspec.yaml.
  static const String fontFamily = 'Manrope';

  /// Bundled fonts for characters Manrope lacks and system fonts don't draw
  /// yet: the Omani rial sign (U+20C4). Every text style lists it.
  static const List<String> fontFamilyFallback = ['MonivoOmaniRial'];

  /// Tabular (fixed-width) figures. Manrope's default digits are
  /// proportional, so every money role switches this on.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  final TextStyle moneyHero;
  final TextStyle moneyDisplay;
  final TextStyle moneyTitle;
  final TextStyle moneyBody;
  final TextStyle moneyCaption;
  final TextStyle eyebrow;

  const AppTypography({
    required this.moneyHero,
    required this.moneyDisplay,
    required this.moneyTitle,
    required this.moneyBody,
    required this.moneyCaption,
    required this.eyebrow,
  });

  /// The one set of roles the app uses. Also the fallback when a widget is
  /// pumped under a plain `ThemeData` in tests.
  static const AppTypography standard = AppTypography(
    moneyHero: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 48,
      height: 1.04,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      fontFeatures: tabularFigures,
    ),
    moneyDisplay: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 32,
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      fontFeatures: tabularFigures,
    ),
    moneyTitle: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      fontFeatures: tabularFigures,
    ),
    moneyBody: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 15,
      height: 1.33,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      fontFeatures: tabularFigures,
    ),
    moneyCaption: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    eyebrow: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );

  @override
  AppTypography copyWith({
    TextStyle? moneyHero,
    TextStyle? moneyDisplay,
    TextStyle? moneyTitle,
    TextStyle? moneyBody,
    TextStyle? moneyCaption,
    TextStyle? eyebrow,
  }) {
    return AppTypography(
      moneyHero: moneyHero ?? this.moneyHero,
      moneyDisplay: moneyDisplay ?? this.moneyDisplay,
      moneyTitle: moneyTitle ?? this.moneyTitle,
      moneyBody: moneyBody ?? this.moneyBody,
      moneyCaption: moneyCaption ?? this.moneyCaption,
      eyebrow: eyebrow ?? this.eyebrow,
    );
  }

  @override
  AppTypography lerp(AppTypography? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      moneyHero: TextStyle.lerp(moneyHero, other.moneyHero, t)!,
      moneyDisplay: TextStyle.lerp(moneyDisplay, other.moneyDisplay, t)!,
      moneyTitle: TextStyle.lerp(moneyTitle, other.moneyTitle, t)!,
      moneyBody: TextStyle.lerp(moneyBody, other.moneyBody, t)!,
      moneyCaption: TextStyle.lerp(moneyCaption, other.moneyCaption, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
    );
  }
}

/// Access to [AppTypography] from a [BuildContext].
extension AppTypographyContext on BuildContext {
  /// Money and eyebrow roles for the current theme, falling back to
  /// [AppTypography.standard] when the theme was not built by `AppTheme`.
  AppTypography get appTypography =>
      Theme.of(this).extension<AppTypography>() ?? AppTypography.standard;
}
