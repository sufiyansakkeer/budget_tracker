import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../settings/domain/entities/currency_entity.dart';

/// From / swap / To.
class CurrencyPairCard extends StatelessWidget {
  final CurrencyEntity source;
  final CurrencyEntity target;

  /// Each swap adds half a turn to the swap icon.
  final int swapCount;
  final VoidCallback onPickSource;
  final VoidCallback onPickTarget;
  final VoidCallback onSwap;

  const CurrencyPairCard({
    super.key,
    required this.source,
    required this.target,
    required this.swapCount,
    required this.onPickSource,
    required this.onPickTarget,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          _CurrencyField(
            key: const Key('converterSourceField'),
            label: 'From',
            currency: source,
            onTap: onPickSource,
          ),
          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              _SwapButton(turns: swapCount / 2, onPressed: onSwap),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),
          _CurrencyField(
            key: const Key('converterTargetField'),
            label: 'To',
            currency: target,
            onTap: onPickTarget,
          ),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  final double turns;
  final VoidCallback onPressed;

  const _SwapButton({required this.turns, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: IconButton.filledTonal(
        key: const Key('converterSwapButton'),
        tooltip: 'Swap currencies',
        onPressed: onPressed,
        icon: AnimatedRotation(
          turns: turns,
          duration: AppMotion.respectReducedMotion(context, AppMotion.medium),
          curve: AppMotion.emphasizedCurve,
          child: const Icon(Icons.swap_vert_rounded),
        ),
      ),
    );
  }
}

class _CurrencyField extends StatelessWidget {
  final String label;
  final CurrencyEntity currency;
  final VoidCallback onTap;

  const _CurrencyField({
    super.key,
    required this.label,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );

    return Semantics(
      button: true,
      label: '$label currency: ${currency.name}, ${currency.code}',
      hint: 'Change currency',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                // Cross-fades the currency when a swap or selection changes it.
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Row(
                    key: ValueKey(currency.code),
                    children: [
                      Container(
                        width: AppSizes.avatarMd,
                        height: AppSizes.avatarMd,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: FittedBox(
                          child: Text(
                            currency.symbol,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currency.code,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              currency.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
