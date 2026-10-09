import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_motion.dart';
import '../currency/currency_formatter.dart';
import '../theme/app_typography.dart';

/// Which money role from [AppTypography] an [AppMoney] is set in.
enum MoneyRole { hero, display, title, body, caption }

/// One amount, formatted and typeset the Monivo way.
///
/// * **Precision follows the currency.** OMR shows fils, JPY shows none, and
///   a whole amount never gains ".00". With [floored] the value is rounded
///   *down* to the digits shown, for anything the user is told they can
///   spend; otherwise it is exact.
/// * **Tabular figures** come from the role, so digits never jitter.
/// * **A true minus.** Negative amounts are drawn with U+2212 before the
///   symbol ("−₹300"). [showPlus] marks inflows ("+₹300"). Ordinary expenses
///   are passed as positive numbers and carry no sign.
/// * **Split** (for hero-sized figures): the currency symbol and the minor
///   units are set at half size, the symbol in [secondaryColor], so the whole
///   units carry the meaning at a glance. Ledgers and lists never split.
/// * **Calm motion.** The first build shows the value as is. A later change
///   cross-fades to the new figure; there is no count-up through amounts
///   that were never true. Reduced motion makes it instant.
///
/// Formatting goes through [CurrencyFormatter] only.
class AppMoney extends StatelessWidget {
  final double amount;

  /// ISO code of the amount's currency. `null` uses the app default.
  final String? currency;
  final MoneyRole role;

  /// Floor to the digits shown (safe amounts) instead of showing it exactly.
  final bool floored;

  /// Set the symbol and the minor units at half size.
  final bool split;

  /// Prefix positive amounts with "+".
  final bool showPlus;

  /// Text colour; defaults to the ambient text colour (ink).
  final Color? color;

  /// Colour of the symbol when [split]; defaults to `onSurfaceVariant`.
  final Color? secondaryColor;

  final TextAlign textAlign;

  /// Overrides the spoken label (defaults to the formatted amount).
  final String? semanticsLabel;

  /// Overrides the role's style entirely (rarely needed).
  final TextStyle? style;

  const AppMoney({
    super.key,
    required this.amount,
    required this.currency,
    this.role = MoneyRole.body,
    this.floored = false,
    this.split = false,
    this.showPlus = false,
    this.color,
    this.secondaryColor,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
    this.style,
  });

  /// The figure as text, exactly as [AppMoney] draws it, for callers that
  /// need it inside a sentence or a semantics label.
  static String format(
    double amount, {
    required String? currency,
    bool floored = false,
    bool showPlus = false,
  }) => _Formatted.of(amount, currency, floored, showPlus).text;

  /// The figure cut into the pieces [split] sets at different sizes, plus
  /// what a screen reader says, for surfaces outside Flutter that typeset it
  /// themselves (the home-screen widget). Same rounding as [format].
  static ({MoneyParts parts, String spoken}) describe(
    double amount, {
    required String? currency,
    bool floored = false,
  }) {
    final f = _Formatted.of(amount, currency, floored, false);
    return (parts: f.parts, spoken: f.spoken);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = _Formatted.of(amount, currency, floored, showPlus);
    final typography = context.appTypography;
    final base = (style ?? _roleStyle(typography)).copyWith(color: color);

    final Widget text = split
        ? Text.rich(
            _splitSpans(
              f,
              base,
              secondaryColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            textAlign: textAlign,
          )
        : Text(f.text, style: base, maxLines: 1, textAlign: textAlign);

    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    final alignment = switch (textAlign) {
      TextAlign.end || TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };

    return Semantics(
      label: semanticsLabel ?? f.spoken,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          layoutBuilder: (current, previous) =>
              Stack(alignment: alignment, children: [...previous, ?current]),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(f.text), child: text),
        ),
      ),
    );
  }

  TextStyle _roleStyle(AppTypography t) => switch (role) {
    MoneyRole.hero => t.moneyHero,
    MoneyRole.display => t.moneyDisplay,
    MoneyRole.title => t.moneyTitle,
    MoneyRole.body => t.moneyBody,
    MoneyRole.caption => t.moneyCaption,
  };

  static InlineSpan _splitSpans(_Formatted f, TextStyle base, Color muted) {
    final size = base.fontSize ?? 14;
    final small = base.copyWith(fontSize: size * 0.5, letterSpacing: 0);
    // Letter spacing after the last glyph of the symbol opens a small gap
    // before the digits without adding a character, so the text still reads
    // exactly as the formatter wrote it.
    final symbol = small.copyWith(
      color: muted,
      fontWeight: FontWeight.w700,
      letterSpacing: size * 0.06,
    );
    final parts = f.parts;
    // The Omani rial sign is set at the height of the figures, as the Central
    // Bank's guidelines require; its own space separates it from them.
    final prefixStyle = parts.prefix.startsWith(CurrencyFormatter.omaniRialSign)
        ? base.copyWith(color: muted)
        : symbol;
    return TextSpan(
      children: [
        if (parts.sign.isNotEmpty) TextSpan(text: parts.sign, style: base),
        if (parts.prefix.isNotEmpty)
          TextSpan(text: parts.prefix, style: prefixStyle),
        TextSpan(text: parts.whole, style: base),
        if (parts.fraction.isNotEmpty)
          TextSpan(text: parts.fraction, style: small),
        if (parts.suffix.isNotEmpty)
          TextSpan(text: parts.suffix, style: symbol),
      ],
    );
  }
}

/// A formatted amount and its pieces.
class _Formatted {
  /// What is drawn, e.g. "−₹1,250.50".
  final String text;

  /// What a screen reader says, e.g. "minus ₹1,250.50".
  final String spoken;
  final MoneyParts parts;

  const _Formatted(this.text, this.spoken, this.parts);

  static _Formatted of(
    double amount,
    String? currency,
    bool floored,
    bool showPlus,
  ) {
    final code = currency ?? '';
    final safe = amount.isFinite ? amount : 0.0;
    final negative = safe < 0;
    final magnitude = safe.abs();

    final double value;
    final int digits;
    if (floored) {
      final display = CurrencyFormatter.floorForDisplay(magnitude, code: code);
      value = display.amount;
      digits = display.decimalDigits;
    } else {
      // Round to the currency's minor units first, so the sign and the
      // digit count describe the figure actually shown.
      final scale = math
          .pow(10, CurrencyFormatter.decimalDigitsFor(code))
          .toDouble();
      value = (magnitude * scale).round() / scale;
      digits = CurrencyFormatter.exactDisplayDigits(value, code: code);
    }

    final body = CurrencyFormatter.format(
      value,
      code: currency,
      decimalDigits: digits,
    );
    // A value that rounds to zero is shown unsigned ("₹0", never "−₹0").
    final isZero = value == 0;
    final sign = isZero
        ? ''
        : negative
        ? '\u2212'
        : (showPlus ? '+' : '');
    final spokenSign = isZero
        ? ''
        : negative
        ? 'minus '
        : (showPlus ? 'plus ' : '');
    final parts = MoneyParts._of(sign, body);
    return _Formatted(
      parts.join(),
      '$spokenSign${CurrencyFormatter.forSpeech(body)}',
      parts,
    );
  }
}

/// A formatted figure cut into sign, symbol, whole units, fraction and any
/// trailing symbol, so a hero figure can size them differently.
class MoneyParts {
  final String sign;
  final String prefix;
  final String whole;
  final String fraction;
  final String suffix;

  const MoneyParts(
    this.sign,
    this.prefix,
    this.whole,
    this.fraction,
    this.suffix,
  );

  /// The figure as drawn (with the left-to-right mark where needed).
  String join() => '$sign$prefix$whole$fraction$suffix';

  static final String _decimalSeparator =
      NumberFormat.currency().symbols.DECIMAL_SEP;

  static MoneyParts _of(String sign, String body) {
    final digit = RegExp(r'\d');
    final first = body.indexOf(digit);
    if (first < 0) return MoneyParts(sign, '', body, '', '');
    var last = body.length - 1;
    while (last > first && !digit.hasMatch(body[last])) {
      last--;
    }
    var prefix = body.substring(0, first);
    final number = body.substring(first, last + 1);
    final suffix = body.substring(last + 1);
    // Arabic-script symbols (د.إ) would pull the digits after them into a
    // right-to-left run and draw "7.600د.إ"; a left-to-right mark after the
    // symbol keeps it in front. CurrencyFormatter normally adds it already.
    if (RegExp(r'[؀-ۿ]').hasMatch(prefix) && !prefix.endsWith('\u200E')) {
      prefix = '$prefix\u200E';
    }

    final sep = number.lastIndexOf(_decimalSeparator);
    if (sep < 0) return MoneyParts(sign, prefix, number, '', suffix);
    return MoneyParts(
      sign,
      prefix,
      number.substring(0, sep),
      number.substring(sep),
      suffix,
    );
  }
}
