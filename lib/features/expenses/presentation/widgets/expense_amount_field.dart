import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

/// Amount input field with currency prefix, decimal support, and inline validation.
class ExpenseAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const ExpenseAmountField({
    super.key,
    required this.controller,
    required this.currencySymbol,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        prefixText: '$currencySymbol ',
        prefixStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondaryLight,
        ),
        errorText: errorText,
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
                tooltip: 'Clear amount',
              ),
      ),
      validator: (_) => errorText,
      onChanged: onChanged,
    );
  }
}
