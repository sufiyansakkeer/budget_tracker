import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';

/// Large amount input with currency prefix, decimal support and inline
/// validation. Autofocuses so adding an expense starts with the number.
class ExpenseAmountField extends StatelessWidget {
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
    this.autofocus = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.displaySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
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
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        prefixText: '$currencySymbol ',
        prefixStyle: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.mlg,
        ),
        errorText: errorText,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              tooltip: 'Clear amount',
            );
          },
        ),
      ),
      validator: (_) => errorText,
      onChanged: onChanged,
    );
  }
}
