import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';

/// Large amount input with currency prefix, decimal support and inline
/// validation. Autofocuses so adding an expense starts with the number.
///
/// While focused the field gets a soft primary glow, so the most important
/// input on the form is unmistakable. Nothing animates while typing.
class ExpenseAmountField extends StatefulWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  const ExpenseAmountField({
    super.key,
    required this.controller,
    required this.currencySymbol,
    this.errorText,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<ExpenseAmountField> createState() => _ExpenseAmountFieldState();
}

class _ExpenseAmountFieldState extends State<ExpenseAmountField> {
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
  void didUpdateWidget(covariant ExpenseAmountField oldWidget) {
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
    final amountStyle = theme.textTheme.displaySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final glow = _focused && widget.errorText == null;

    return AnimatedContainer(
      duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
      curve: AppMotion.standardCurve,
      decoration: BoxDecoration(
        borderRadius: AppSpacing.borderRadiusMd,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        style: amountStyle,
        decoration: InputDecoration(
          labelText: 'Amount',
          hintText: '0.00',
          hintStyle: amountStyle?.copyWith(
            // A hint still has to be readable; 20% opacity is ~1.5:1.
            color: theme.colorScheme.onSurfaceVariant,
          ),
          prefixText: '${widget.currencySymbol} ',
          prefixStyle: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.mlg,
          ),
          errorText: widget.errorText,
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              return AnimatedSwitcher(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.fast,
                ),
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
              );
            },
          ),
        ),
        validator: (_) => widget.errorText,
        onChanged: widget.onChanged,
      ),
    );
  }
}
