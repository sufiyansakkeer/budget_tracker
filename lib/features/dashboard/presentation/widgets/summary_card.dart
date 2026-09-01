import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final Color? backgroundColor;
  final Color? valueColor;
  final IconData? icon;
  final bool isHighlighted;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    this.backgroundColor,
    this.valueColor,
    this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = backgroundColor ?? theme.cardTheme.color;
    final valueColorValue = valueColor ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppSpacing.borderRadiusLg,
        border: isHighlighted
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Semantics(
        label: _semanticLabel(title, amount, currency),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isHighlighted ? theme.colorScheme.primary : valueColorValue,
                size: 24,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColorValue.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isHighlighted
                  ? 'You can safely spend'
                  : NumberFormat.currency(
                      symbol: currency,
                      decimalDigits: 0,
                    ).format(amount),
              style: theme.textTheme.titleLarge?.copyWith(
                color: valueColorValue,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isHighlighted) ...[
              const SizedBox(height: AppSpacing.xs),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: amount),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    NumberFormat.currency(
                      symbol: currency,
                      decimalDigits: 0,
                    ).format(value),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _semanticLabel(String title, double amount, String currency) {
    final symbol = currency.isEmpty ? '' : '$currency ';
    final formatted = NumberFormat.currency(
      symbol: '',
      decimalDigits: 0,
    ).format(amount);
    if (title.isEmpty) {
      return 'Daily safe spending: $symbol$formatted';
    }
    return '$title: $symbol$formatted';
  }
}
