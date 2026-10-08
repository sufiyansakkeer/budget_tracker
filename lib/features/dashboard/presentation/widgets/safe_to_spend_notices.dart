import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'safe_to_spend_copy.dart';

/// What today's amount does not include, each as a quiet notice with its
/// own action:
/// bills that could not be loaded, upcoming bills no budget sets aside
/// ("Link bills"), and linked bills in another currency.
///
/// Renders nothing when everything is included ([hasNotices] is false). The
/// notices themselves are not tappable; the action is a separate button, so
/// no tap target is nested in another.
class SafeToSpendNotices extends StatelessWidget {
  final SafeToSpendEntity safeToSpend;

  /// Opens the "Link bills" sheet; the action is hidden when null.
  final VoidCallback? onLinkBills;

  /// Reloads the dashboard; the action is hidden when null.
  final VoidCallback? onRetry;

  const SafeToSpendNotices({
    super.key,
    required this.safeToSpend,
    this.onLinkBills,
    this.onRetry,
  });

  static bool hasNotices(SafeToSpendEntity e) =>
      !e.commitmentsAvailable ||
      !e.unlinked.isEmpty ||
      !e.currencyExcluded.isEmpty;

  @override
  Widget build(BuildContext context) {
    final e = safeToSpend;
    final notices = <Widget>[
      if (!e.commitmentsAvailable)
        AppNotice(
          key: const ValueKey('notice_bills_unavailable'),
          tone: AppTone.caution,
          icon: Icons.cloud_off_rounded,
          title: 'Bills not included',
          message:
              "Bills couldn't be loaded, so they aren't included. Today's "
              'amount may be too high.',
          action: onRetry == null
              ? null
              : TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      if (!e.unlinked.isEmpty)
        AppNotice(
          key: const ValueKey('notice_bills_not_linked'),
          tone: AppTone.info,
          icon: Icons.link_off_rounded,
          title: 'Bills not linked',
          message: SafeToSpendCopy.notLinked(e.unlinked, e.currency),
          action: onLinkBills == null
              ? null
              : TextButton(
                  onPressed: onLinkBills,
                  child: const Text('Link bills'),
                ),
        ),
      if (!e.currencyExcluded.isEmpty)
        AppNotice(
          key: const ValueKey('notice_bills_other_currency'),
          tone: AppTone.info,
          icon: Icons.currency_exchange_rounded,
          title: 'Bills in another currency',
          message: SafeToSpendCopy.currencyExcluded(
            e.currencyExcluded,
            e.currency,
          ),
        ),
    ];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < notices.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          notices[i],
        ],
      ],
    );
  }
}
