import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';

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
    final symbol = showSymbol ? currency : '';
    final formatted = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(amount);
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

/// Convenience status colors for money values.
class MoneyColor {
  MoneyColor._();

  static const Color positive = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color negative = AppColors.error;
  static const Color neutral = AppColors.primary;
}
