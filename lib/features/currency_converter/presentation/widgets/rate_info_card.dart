import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/entities/rate_lookup.dart';
import 'converter_copy.dart';

/// "1 OMR = ₹249.33", where that rate came from, and "Refresh rate".
class RateInfoCard extends StatelessWidget {
  final RateLookup lookup;
  final CurrencyEntity target;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  /// Injectable for tests; defaults to the current time.
  final DateTime? now;

  const RateInfoCard({
    super.key,
    required this.lookup,
    required this.target,
    required this.isRefreshing,
    required this.onRefresh,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final now = this.now ?? DateTime.now();
    final rate = lookup.rate;
    final isIdentity = lookup.origin == RateOrigin.identity;

    final rateText =
        '1 ${rate.baseCurrency} = ${CurrencyFormatter.formatRate(rate.rate, symbol: target.symbol, code: target.code)}';

    final (chipColor, chipIcon) = switch (lookup) {
      RateLookup(fallbackReason: final reason?) when reason.isOffline => (
        colors.warning,
        Icons.wifi_off_rounded,
      ),
      RateLookup(fallbackReason: _?) => (
        colors.warning,
        Icons.sync_problem_rounded,
      ),
      RateLookup(origin: RateOrigin.online) => (
        colors.success,
        Icons.cloud_done_rounded,
      ),
      RateLookup(origin: RateOrigin.cached) => (
        colors.info,
        Icons.save_rounded,
      ),
      RateLookup(origin: RateOrigin.identity) => (
        colors.info,
        Icons.drag_handle_rounded,
      ),
    };

    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return AppCard(
      key: const Key('converterRateCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exchange rate',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              StatusChip(
                label: ConverterCopy.sourceLabel(lookup),
                color: chipColor,
                icon: chipIcon,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // A refresh that lands a new rate or date re-keys this block, so
          // the update is visible even when the number barely moves.
          AnimatedSwitcher(
            duration: AppMotion.respectReducedMotion(
              context,
              AppMotion.standard,
            ),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, if (current != null) current],
            ),
            child: Column(
              key: ValueKey('${rate.id}-${rate.rate}-${rate.fetchedAt}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rateText,
                  key: const Key('converterRateText'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ConverterCopy.sourceDetail(lookup, now),
                  key: const Key('converterRateSource'),
                  style: theme.textTheme.bodyMedium,
                ),
                if (!isIdentity) ...[
                  Text(
                    ConverterCopy.fetchedLabel(lookup, now),
                    style: secondary,
                  ),
                  if (lookup.derived)
                    Text(ConverterCopy.derivedNote(lookup), style: secondary),
                ],
              ],
            ),
          ),
          if (!isIdentity) ...[
            const SizedBox(height: AppSpacing.smd),
            Text(ConverterCopy.disclaimer, style: secondary),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('converterRefreshButton'),
                onPressed: isRefreshing ? null : onRefresh,
                icon: AnimatedSwitcher(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.fast,
                  ),
                  child: isRefreshing
                      ? const SizedBox(
                          key: ValueKey('spinner'),
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          key: ValueKey('icon'),
                        ),
                ),
                label: Text(isRefreshing ? 'Refreshing…' : 'Refresh rate'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
