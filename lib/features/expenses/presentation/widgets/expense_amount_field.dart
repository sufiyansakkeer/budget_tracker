import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

/// Amount input field with currency prefix, decimal support, and inline validation.
///
/// Features a large, visual amount display with autofocus for a fast
/// add-expense flow.
class ExpenseAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const ExpenseAmountField({
    super.key,
    required this.controller,
    required this.currencySymbol,
    this.errorText,
    this.onChanged,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: theme.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        hintStyle: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        prefixText: '$currencySymbol ',
        prefixStyle: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        errorText: errorText,
        errorStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => controller.clear(),
                tooltip: 'Clear amount',
              ),
      ),
      validator: (_) => errorText,
      onChanged: onChanged,
    );
  }
}
