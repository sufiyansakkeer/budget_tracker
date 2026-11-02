import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../domain/entities/pay_later_overview.dart';
import '../bloc/pay_later_summary_cubit.dart';
import 'tab_tile.dart';

/// Home's "Pay later" section: what is owed on tabs, one line per currency
/// (never added across currencies), the next settle-up day and what is
/// overdue. One tap opens the overview.
///
/// Renders nothing, and takes no space, until there is a tab worth showing:
/// not while loading, not when the summary could not be read, and not when
/// there is no tab that is active or still has a balance.
class PayLaterHomeRow extends StatelessWidget {
  /// The sections above it use [AppSpacing.xl]; the gap lives here so an
  /// empty row adds none.
  static const double _topGap = AppSpacing.xl;

  /// Position in Home's entrance sequence.
  final int index;

  const PayLaterHomeRow({super.key, this.index = 3});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayLaterSummaryCubit, PayLaterOverview?>(
      builder: (context, overview) {
        if (overview == null || !_shows(overview)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: _topGap),
          child: FadeSlideIn(
            index: index,
            child: _PayLaterSection(overview: overview),
          ),
        );
      },
    );
  }

  /// A tab is active, or an archived one still owes or holds credit.
  static bool _shows(PayLaterOverview overview) =>
      overview.activeTabCount > 0 ||
      overview.tabs.any(PayLaterOverview.hasBalance);
}

class _PayLaterSection extends StatelessWidget {
  final PayLaterOverview overview;

  const _PayLaterSection({required this.overview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The overview's own day: a reload on a new day is a new state, so
    // "tomorrow" can't outlive midnight.
    final today = overview.today;
    final owing = [
      for (final totals in overview.totals)
        if (totals.owed > 0) totals,
    ];
    final overdueCount = owing.where((t) => t.overdue > 0).length;
    return AppSection(
      key: const Key('payLaterHomeRow'),
      title: 'Pay later',
      subtitle: overdueCount == 0 ? null : 'Something is overdue',
      action: TextButton(
        onPressed: () => context.pushUnique(AppRouter.payLaterPath),
        child: const Text('See all'),
      ),
      child: AppGroupedList(
        dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
        children: [
          if (owing.isEmpty)
            AppListRow(
              key: const Key('payLaterHomeNothingOwed'),
              leading: IconTile(
                icon: Icons.credit_card_outlined,
                color: theme.colorScheme.primary,
                size: AppSizes.avatarSm,
              ),
              title: 'Nothing owed',
              subtitle: 'Your tabs are settled',
              onTap: () => context.pushUnique(AppRouter.payLaterPath),
            ),
          for (final totals in owing)
            _CurrencyRow(
              totals: totals,
              settleUp: _nextSettleUp(totals.currency),
              today: today,
            ),
        ],
      ),
    );
  }

  /// The soonest settle-up day among tabs in [currency].
  DateTime? _nextSettleUp(String currency) {
    for (final (tab, day) in overview.upcoming) {
      if (tab.currency == currency) return day;
    }
    return null;
  }
}

class _CurrencyRow extends StatelessWidget {
  final CurrencyTotals totals;
  final DateTime? settleUp;
  final DateTime today;

  const _CurrencyRow({
    required this.totals,
    required this.settleUp,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = totals.overdue > 0;
    final overdueText =
        '${AppMoney.format(totals.overdue, currency: totals.currency)} overdue';
    final String? settleText = settleUp == null
        ? null
        : 'Next settle-up ${TabTile.relativeDay(settleUp!, today: today)}';
    final spoken = [
      'owed ${AppMoney.format(totals.owed, currency: totals.currency)}',
      if (overdue) overdueText,
      ?settleText,
    ].join(', ');
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AppListRow(
      key: ValueKey('payLaterHome_${totals.currency}'),
      leading: IconTile(
        icon: Icons.credit_card_outlined,
        color: overdue
            ? context.tone(AppTone.critical).accent
            : theme.colorScheme.primary,
        size: AppSizes.avatarSm,
      ),
      title: 'You owe',
      subtitleWidget: (overdue || settleText != null)
          ? Text.rich(
              TextSpan(
                children: [
                  if (overdue)
                    TextSpan(
                      text: overdueText,
                      style: TextStyle(
                        color: context.tone(AppTone.critical).accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (overdue && settleText != null)
                    const TextSpan(text: ' · '),
                  if (settleText != null) TextSpan(text: settleText),
                ],
              ),
              style: style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: AppMoney(
        amount: totals.owed,
        currency: totals.currency,
        textAlign: TextAlign.end,
      ),
      semanticLabel: 'Pay later, $spoken',
      onTap: () => context.pushUnique(AppRouter.payLaterPath),
    );
  }
}
