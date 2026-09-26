import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/exact_decimal.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/entities/exchange_rate_failure.dart';
import '../../domain/entities/rate_lookup.dart';
import 'converter_copy.dart';

/// The converted amount, or why there isn't one.
///
/// Content only animates when the pair or the rate changes. Typing updates
/// the numbers in place, because a transition per keystroke is noise.
class ConversionResultCard extends StatelessWidget {
  final CurrencyEntity source;
  final CurrencyEntity target;
  final ExactDecimal? amount;
  final ExactDecimal? result;
  final RateLookup? rate;
  final ExchangeRateFailure? failure;
  final VoidCallback onRetry;

  const ConversionResultCard({
    super.key,
    required this.source,
    required this.target,
    required this.amount,
    required this.result,
    required this.rate,
    required this.failure,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFailure = failure != null && rate == null;
    final Widget child;
    if (hasFailure) {
      child = _Failure(
        key: const ValueKey('failure'),
        failure: failure!,
        base: source.code,
        quote: target.code,
        onRetry: onRetry,
      );
    } else if (rate == null) {
      child = const _Loading(key: ValueKey('loading'));
    } else {
      child = _Result(
        key: ValueKey('result-${rate!.rate.id}-${rate!.rate.rate}'),
        source: source,
        target: target,
        amount: amount,
        result: result,
      );
    }

    return AppCard(
      key: const Key('converterResultCard'),
      color: hasFailure ? null : scheme.primaryContainer,
      showBorder: hasFailure,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AnimatedSwitcher(
        duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final CurrencyEntity source;
  final CurrencyEntity target;
  final ExactDecimal? amount;
  final ExactDecimal? result;

  const _Result({
    super.key,
    required this.source,
    required this.target,
    required this.amount,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    final amount = this.amount;
    final result = this.result;

    if (amount == null || result == null) {
      return Text(
        'Enter an amount to see the conversion',
        style: theme.textTheme.titleMedium?.copyWith(color: onContainer),
      );
    }

    final sourceDigits = CurrencyFormatter.decimalDigitsFor(source.code);
    final sourceText = CurrencyFormatter.formatDecimal(
      amount,
      symbol: source.symbol,
      // Never hide decimals the user typed.
      decimalDigits: amount.scale > sourceDigits ? amount.scale : sourceDigits,
    );
    final resultText = CurrencyFormatter.formatDecimal(
      result,
      symbol: target.symbol,
      decimalDigits: CurrencyFormatter.decimalDigitsFor(target.code),
    );

    return Semantics(
      liveRegion: true,
      label: '$sourceText ${source.code} is about $resultText ${target.code}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sourceText ${source.code} ≈',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(color: onContainer),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              resultText,
              key: const Key('converterResultText'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: onContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${target.name} · ${target.code}',
            style: theme.textTheme.bodyMedium?.copyWith(color: onContainer),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading exchange rate',
      child: const Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 120, height: 14),
            SizedBox(height: AppSpacing.smd),
            SkeletonBox(width: 200, height: 36),
            SizedBox(height: AppSpacing.smd),
            SkeletonBox(width: 140, height: 14),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  final ExchangeRateFailure failure;
  final String base;
  final String quote;
  final VoidCallback onRetry;

  const _Failure({
    super.key,
    required this.failure,
    required this.base,
    required this.quote,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              failure.isOffline
                  ? Icons.wifi_off_rounded
                  : Icons.cloud_off_rounded,
              color: scheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                ConverterCopy.failureTitle(failure),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ConverterCopy.failureMessage(failure, base: base, quote: quote),
          key: const Key('converterFailureMessage'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          key: const Key('converterRetryButton'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}
