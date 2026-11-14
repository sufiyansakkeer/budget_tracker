import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import '../currency/currency_formatter.dart';
import '../currency/money_input.dart';
import '../currency/money_input_formatter.dart';

/// The app's one money input (UX-110): every amount the user types goes
/// through it.
///
/// * Typing follows [MoneyInput]: [MoneyInputFormatter] with the currency's
///   minor units (never fewer than two), so a form never rejects what its
///   field let through, and a pasted "1,250.00" keeps its thousands.
/// * The currency symbol is the prefix once [currency] is known. While it
///   is null there is no prefix at all, never a stand-in ₹ (UX-082). An
///   unknown code shows the code itself.
/// * The decoration is the theme's [InputDecorationTheme]; the amount uses
///   tabular figures and the symbol the primary colour.
/// * Each screen keeps its own rules through [validator] (checked by the
///   enclosing [Form]) or [errorText] (set by the screen after a save).
///
/// [hero] is the larger look for a screen whose main input is the amount
/// (the expense form, a payment, onboarding): bigger figures, a soft glow
/// while focused and a clear button.
class AppAmountField extends StatefulWidget {
  final TextEditingController controller;

  /// The ISO code the amount is in, or null while it is not known yet.
  final String? currency;

  /// Shown instead of [currency]'s own symbol, for a symbol resolved
  /// elsewhere (the converter's provider symbols, onboarding's choice).
  final String? symbol;

  /// Decimals the amount may have. Defaults to
  /// [MoneyInput.maxDecimals] for [currency].
  final int? decimals;

  final String label;

  /// Defaults to zero at the currency's own decimals ("0.00", OMR "0.000",
  /// JPY "0").
  final String? hintText;
  final String? helperText;

  /// An error the screen sets itself, for example after Save.
  final String? errorText;

  /// The screen's own rules (limits, required), checked by its [Form].
  /// Without one, the field reports [errorText] to the form.
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final IconData? prefixIcon;
  final bool hero;

  const AppAmountField({
    super.key,
    required this.controller,
    required this.currency,
    this.symbol,
    this.decimals,
    this.label = 'Amount',
    this.hintText,
    this.helperText,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.prefixIcon,
    this.hero = false,
  });

  /// The prefix for [currency], or null while it is unknown.
  static String? symbolFor(String? currency) =>
      currency == null || currency.isEmpty
      ? null
      : CurrencyFormatter.resolveSymbol(currency);

  /// Zero written with [currency]'s own decimals: "0.00", "0.000", "0".
  static String zeroFor(String? currency) {
    final digits = currency == null || currency.isEmpty
        ? 2
        : CurrencyFormatter.decimalDigitsFor(currency);
    return digits <= 0 ? '0' : '0.${'0' * digits}';
  }

  @override
  State<AppAmountField> createState() => _AppAmountFieldState();
}

class _AppAmountFieldState extends State<AppAmountField> {
  FocusNode? _ownedNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
    _focused = _node.hasFocus;
  }

  @override
  void didUpdateWidget(covariant AppAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedNode)?.removeListener(_onFocusChanged);
      _node.addListener(_onFocusChanged);
      _focused = _node.hasFocus;
    }
  }

  void _onFocusChanged() {
    if (!mounted || _focused == _node.hasFocus) return;
    setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChanged);
    _ownedNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hero = widget.hero;
    final amountStyle =
        (hero ? theme.textTheme.displaySmall : theme.textTheme.titleLarge)
            ?.copyWith(
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    final symbol = widget.symbol ?? AppAmountField.symbolFor(widget.currency);
    final decimals = widget.decimals ?? MoneyInput.maxDecimals(widget.currency);

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _node,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: widget.textInputAction,
      // The iOS decimal pad has no Done key: a tap anywhere else closes it.
      onTapOutside: (_) => _node.unfocus(),
      inputFormatters: [MoneyInputFormatter(decimals)],
      style: amountStyle,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText ?? AppAmountField.zeroFor(widget.currency),
        // A hint still has to be readable; 20% opacity is ~1.5:1.
        hintStyle: amountStyle?.copyWith(color: scheme.onSurfaceVariant),
        helperText: widget.helperText,
        helperMaxLines: 2,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        prefixText: symbol == null || symbol.isEmpty ? null : '$symbol ',
        prefixStyle:
            (hero ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)
                ?.copyWith(color: scheme.primary),
        contentPadding: hero
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.mlg,
              )
            : null,
        errorText: widget.errorText,
        suffixIcon: hero ? _clearButton() : null,
      ),
      autovalidateMode: widget.autovalidateMode,
      validator: widget.validator ?? (_) => widget.errorText,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
    );
    if (!hero) return field;

    // The amount is the screen's main input: a soft primary glow while
    // focused makes that unmistakable. Nothing animates while typing.
    final glow = _focused && widget.errorText == null;
    return AnimatedContainer(
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      curve: AppMotion.standardCurve,
      decoration: BoxDecoration(
        borderRadius: AppSpacing.borderRadiusSm,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: field,
    );
  }

  Widget _clearButton() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: widget.controller,
    builder: (context, value, _) => AnimatedSwitcher(
      duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: value.text.isEmpty
          ? const SizedBox.shrink(key: ValueKey('noClear'))
          : IconButton(
              key: const ValueKey('clear'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                widget.controller.clear();
                widget.onChanged?.call('');
              },
              tooltip: 'Clear amount',
            ),
    ),
  );
}
