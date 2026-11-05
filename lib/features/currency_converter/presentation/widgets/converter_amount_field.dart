import 'package:flutter/material.dart';

import '../../../../core/widgets/app_amount_field.dart';
import '../../domain/validators/amount_input_validator.dart';

/// The amount to convert, prefixed with the source currency's symbol: the
/// app's one amount field, at the source currency's precision.
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
    return AppAmountField(
      key: const Key('converterAmountField'),
      controller: controller,
      currency: currencyCode,
      // The provider's symbol, resolved by the converter (never ₹ for a
      // code the app doesn't know).
      symbol: symbol,
      label: 'Amount in $currencyCode',
      errorText: error?.message,
      onChanged: onChanged,
    );
  }
}
