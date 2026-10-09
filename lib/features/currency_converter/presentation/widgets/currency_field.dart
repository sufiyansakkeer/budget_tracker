import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../settings/domain/entities/currency_entity.dart';

/// A hairline across the converter with the swap button in the middle.
class SwapDivider extends StatelessWidget {
  /// Each swap adds half a turn to the icon.
  final int swapCount;
  final VoidCallback onPressed;

  const SwapDivider({
    super.key,
    required this.swapCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
    );
    final turns = swapCount / 2;
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: IconButton.filledTonal(
            key: const Key('converterSwapButton'),
            tooltip: 'Swap currencies',
            onPressed: onPressed,
            icon: AnimatedRotation(
              turns: turns,
              duration: AppMotion.respectReducedMotion(
                context,
                AppMotion.medium,
              ),
              curve: AppMotion.emphasizedCurve,
              child: const Icon(Icons.swap_vert_rounded),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// A currency the converter converts from or to: its label, symbol, code
/// and name, with a tap that opens the currency picker.
class CurrencyField extends StatelessWidget {
  final String label;
  final CurrencyEntity currency;
  final VoidCallback onTap;

  const CurrencyField({
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
              // At least 48 dp so From and To line up; wider at large text
              // sizes rather than breaking the word.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Text(
                  label,
                  softWrap: false,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
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
