import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/validators/amount_input_validator.dart';

/// The amount to convert, prefixed with the source currency's symbol.
class ConverterAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String symbol;
  final String currencyCode;
  final AmountInputError? error;
  final ValueChanged<String> onChanged;

  const ConverterAmountField({
    super.key,
    required this.controller,
    required this.symbol,
    required this.currencyCode,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      key: const Key('converterAmountField'),
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: const [AmountTextInputFormatter()],
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'Amount in $currencyCode',
        hintText: '0',
        prefixText: '$symbol ',
        prefixStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        errorText: error?.message,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

/// Lets through digits and a single decimal separator (`.` or `,`), with at
/// most [AmountInputValidator.maxFractionDigits] decimals and 13 integer
/// digits. Anything else (letters, a second separator, a minus sign) is
/// rejected keystroke by keystroke, so the field can never hold text the
/// validator would call invalid characters.
class AmountTextInputFormatter extends TextInputFormatter {
  const AmountTextInputFormatter();

  static final RegExp _allowed = RegExp(r'^\d{0,13}([.,]\d{0,8})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (_allowed.hasMatch(text)) {
      return text == newValue.text
          ? newValue
          : TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
    }
    return oldValue;
  }
}
