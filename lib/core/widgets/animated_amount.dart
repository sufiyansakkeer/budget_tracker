import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../currency/currency_formatter.dart';

/// A money value that animates from its previous amount to the new one.
///
/// Uses [TweenAnimationBuilder], so the first build shows the final value
/// immediately (no distracting count-up on screen entry) and only *changes*
/// are animated. Long values are scaled down instead of overflowing.
///
/// The displayed value always settles on the real [amount]; intermediate
/// frames are presentation only and never touch application state.
class AnimatedAmount extends StatelessWidget {
  final double amount;
  final String? currency;
  final TextStyle? style;
  final int decimalDigits;
  final TextAlign textAlign;

  /// When true, the amount is rendered with a leading minus sign.
  final bool negative;

  const AnimatedAmount({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.decimalDigits = 0,
    this.textAlign = TextAlign.start,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = CurrencyFormatter.format(
      amount,
      code: currency,
      decimalDigits: decimalDigits,
    );
    return Semantics(
      label: negative ? 'minus $formatted' : formatted,
      child: ExcludeSemantics(
        child: _AnimatedValue(
          value: amount,
          builder: (context, value) {
            final text = CurrencyFormatter.format(
              value,
              code: currency,
              decimalDigits: decimalDigits,
            );
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: textAlign == TextAlign.end
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                negative ? '−$text' : text,
                style: style,
                maxLines: 1,
                textAlign: textAlign,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A percentage value (0–100) that animates between changes.
///
/// [suffix] follows the number, e.g. `'% used'`.
class AnimatedPercent extends StatelessWidget {
  final double percent;
  final TextStyle? style;
  final String suffix;
  final TextAlign? textAlign;

  const AnimatedPercent({
    super.key,
    required this.percent,
    this.style,
    this.suffix = '%',
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedValue(
      value: percent,
      builder: (context, value) => Text(
        '${value.toStringAsFixed(0)}$suffix',
        style: style,
        maxLines: 1,
        textAlign: textAlign,
      ),
    );
  }
}

/// Any numeric value that animates between changes, formatted by [format].
///
/// Use for counts, day numbers or custom money layouts where
/// [AnimatedAmount] does not fit.
class AnimatedNumber extends StatelessWidget {
  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedValue(
      value: value,
      builder: (context, v) =>
          Text(format(v), style: style, maxLines: 1, textAlign: textAlign),
    );
  }
}

class _AnimatedValue extends StatefulWidget {
  final double value;
  final Widget Function(BuildContext context, double value) builder;

  const _AnimatedValue({required this.value, required this.builder});

  @override
  State<_AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<_AnimatedValue> {
  /// Set on the first build so the initial value renders without a count-up.
  bool _first = true;

  @override
  void didUpdateWidget(covariant _AnimatedValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _first = false;
  }

  @override
  Widget build(BuildContext context) {
    final safe = widget.value.isFinite ? widget.value : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: safe),
      duration: _first
          ? Duration.zero
          : AppMotion.respectReducedMotion(context, AppMotion.emphasized),
      curve: AppMotion.value,
      builder: (context, value, _) => widget.builder(context, value),
    );
  }
}
