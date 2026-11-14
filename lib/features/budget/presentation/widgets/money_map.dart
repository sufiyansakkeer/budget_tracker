import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../dashboard/presentation/widgets/safe_to_spend_copy.dart';
import '../../domain/entities/safe_to_spend/safe_to_spend_entity.dart';

/// Where a budget's whole amount is: spent, bills due, kept aside, the
/// savings goal and what is free to spend, as one bar in proportion and a
/// row for each part. Free money that bills and set-asides overrun reads
/// "… short", in red, and draws nothing.
///
/// All figures are the engine's ([SafeToSpendEntity]); nothing is computed
/// here but the bar's proportions.
class MoneyMap extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;

  const MoneyMap({super.key, required this.safeToSpend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final e = safeToSpend;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final parts = <_Part>[
      _Part('spent', 'Spent', e.periodSpent, colorScheme.onSurface),
      _Part(
        'bills',
        'Bills due',
        e.commitmentsAvailable && e.upcomingCommitments > 0
            ? e.upcomingCommitments
            : null,
        colorScheme.tertiary,
        none: e.commitmentsAvailable ? 'None' : "Couldn't load",
      ),
      _Part('kept', 'Kept aside', e.reservedAmount, colorScheme.secondary),
      _Part(
        'savings',
        'Savings goal',
        e.remainingSavingsTarget,
        colorScheme.outline,
      ),
      _Part(
        'free',
        'Free to spend',
        e.shortfall > 0 ? null : e.freeToSpend,
        colorScheme.primary,
      ),
    ];
    final drawn = [
      for (final p in parts)
        if ((p.amount ?? 0) > 0) p,
    ];
    final total = drawn.fold<double>(0, (sum, p) => sum + p.amount!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Where the ${AppMoney.format(e.budgetAmount, currency: e.currency)} is',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        if (total > 0)
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: AppSpacing.borderRadiusSm,
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    for (final p in drawn)
                      Expanded(
                        key: Key('money_map_${p.id}'),
                        // Thousandths of the whole; a sliver stays visible.
                        flex: (p.amount! / total * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: p.color),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final p in parts)
          _row(context, p, muted, short: p.id == 'free' && e.shortfall > 0),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    _Part p,
    TextStyle? muted, {
    required bool short,
  }) {
    final theme = Theme.of(context);
    final e = safeToSpend;
    final String spoken;
    final Widget value;
    if (short) {
      final text = SafeToSpendCopy.freeToSpendValue(e);
      spoken = text;
      value = Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (p.amount == null) {
      spoken = p.none;
      value = Text(p.none, style: muted);
    } else {
      final floored = p.id == 'free';
      spoken = AppMoney.format(
        p.amount!,
        currency: e.currency,
        floored: floored,
      );
      value = AppMoney(
        amount: p.amount!,
        currency: e.currency,
        floored: floored,
        textAlign: TextAlign.end,
      );
    }
    return Semantics(
      label: CurrencyFormatter.forSpeech('${p.label}, $spoken'),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: (p.amount ?? 0) > 0 ? p.color : null,
                border: (p.amount ?? 0) > 0
                    ? null
                    : Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(child: Text(p.label, style: theme.textTheme.bodyLarge)),
            const SizedBox(width: AppSpacing.sm),
            value,
          ],
        ),
      ),
    );
  }
}

class _Part {
  final String id;
  final String label;

  /// Null when not set (or, for bills, when they could not be read).
  final double? amount;
  final Color color;
  final String none;

  const _Part(
    this.id,
    this.label,
    this.amount,
    this.color, {
    this.none = 'Not set',
  });
}
