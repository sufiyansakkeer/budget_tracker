import 'package:flutter/material.dart';

import '../currency/currency_formatter.dart';
import '../theme/app_colors_extension.dart';

/// Formats a money value with strong visual hierarchy.
///
/// The amount is the primary visual focus; the optional [label] is shown as a
/// smaller caption above it. Use [color] for semantic status (success/warning/
/// error) where appropriate.
class MoneyText extends StatelessWidget {
  final double amount;
  final String currency;
  final String? label;
  final TextStyle? amountStyle;
  final Color? color;
  final int decimalDigits;
  final bool showSymbol;

  const MoneyText({
    super.key,
    required this.amount,
    this.currency = '',
    this.label,
    this.amountStyle,
    this.color,
    this.decimalDigits = 0,
    this.showSymbol = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = showSymbol
        ? CurrencyFormatter.format(
            amount,
            code: currency,
            decimalDigits: decimalDigits,
          )
        : CurrencyFormatter.format(
            amount,
            code: '',
            decimalDigits: decimalDigits,
          );
    final textColor = color ?? theme.colorScheme.onSurface;

    final Column content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
        ],
        Text(
          formatted,
          style:
              amountStyle ??
              theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Semantics(
      label: label == null ? formatted : '$label: $formatted',
      child: content,
    );
  }
}

/// Convenience status colors for money values using the active palette.
class MoneyColor {
  MoneyColor._();

  /// Returns palette-aware semantic color for positive/progress values.
  static Color positive(BuildContext context) => context.appColors.success;

  /// Returns palette-aware semantic color for warning values.
  static Color warning(BuildContext context) => context.appColors.warning;

  /// Returns palette-aware semantic color for negative/expense values.
  static Color negative(BuildContext context) => context.appColors.error;

  /// Returns palette-aware primary color.
  static Color neutral(BuildContext context) => context.appColors.primary;

  /// Returns palette-aware income color.
  static Color income(BuildContext context) => context.appColors.income;

  /// Returns palette-aware expense color.
  static Color expense(BuildContext context) => context.appColors.expense;
}
