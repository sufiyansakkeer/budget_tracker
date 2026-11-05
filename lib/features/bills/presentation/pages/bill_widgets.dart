import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../bloc/bill_state.dart';
import '../../../../core/dates/date_range_format.dart';

/// Shared icon / status mapping for bills so the list, details and dashboard
/// always draw a bill the same way.
class BillVisuals {
  BillVisuals._();

  /// The time a bill without one is due (and reminded) at: the domain's
  /// 9:00 default ([BillEntity.reminderDateTime]). Show it with
  /// `format(context)` so it follows the 12/24-hour setting.
  static const TimeOfDay defaultDueTime = TimeOfDay(hour: 9, minute: 0);

  static IconData iconFor(BillCategory category) {
    switch (category) {
      case BillCategory.rent:
        return Icons.home_rounded;
      case BillCategory.utilities:
        return Icons.bolt_rounded;
      case BillCategory.electricity:
        return Icons.electric_bolt_rounded;
      case BillCategory.water:
        return Icons.water_drop_rounded;
      case BillCategory.internet:
        return Icons.wifi_rounded;
      case BillCategory.phone:
        return Icons.phone_rounded;
      case BillCategory.emi:
        return Icons.payments_rounded;
      case BillCategory.insurance:
        return Icons.shield_rounded;
      case BillCategory.subscription:
        return Icons.subscriptions_rounded;
      case BillCategory.education:
        return Icons.school_rounded;
      case BillCategory.healthcare:
        return Icons.local_hospital_rounded;
      case BillCategory.government:
        return Icons.account_balance_rounded;
      case BillCategory.creditCard:
        return Icons.credit_card_rounded;
      case BillCategory.other:
        return Icons.receipt_long_rounded;
    }
  }

  /// Semantic colour for a status.
  static Color colorFor(BuildContext context, BillStatus status) {
    final colors = context.appColors;
    return switch (status) {
      BillStatus.paid => colors.success,
      BillStatus.overdue => colors.error,
      BillStatus.dueToday => colors.warning,
      BillStatus.upcoming => colors.info,
    };
  }

  static IconData statusIcon(BillStatus status) => switch (status) {
    BillStatus.paid => Icons.check_circle_rounded,
    BillStatus.overdue => Icons.error_rounded,
    BillStatus.dueToday => Icons.today_rounded,
    BillStatus.upcoming => Icons.schedule_rounded,
  };

  static String statusLabel(BillStatus status) => switch (status) {
    BillStatus.paid => 'Paid',
    BillStatus.overdue => 'Overdue',
    BillStatus.dueToday => 'Due today',
    BillStatus.upcoming => 'Upcoming',
  };

  /// Chip combining icon + label + colour for a status. The label wraps
  /// rather than overflowing at large text sizes.
  static StatusChip chip(BuildContext context, BillStatus status) => StatusChip(
    label: statusLabel(status),
    color: colorFor(context, status),
    icon: statusIcon(status),
    wrapLabel: true,
  );

  /// Unpaid bills due within this many days (today included) are "Due
  /// soon" in the list; later ones are "Later".
  static const int dueSoonDays = BillState.dueSoonDays;

  /// Whether an unpaid, not-overdue [bill] is due within [dueSoonDays] of
  /// [now]'s calendar day.
  static bool isDueSoon(BillEntity bill, DateTime now) =>
      BillState.isDueSoon(bill, now);

  /// The amounts of [bills] per currency, summed exactly in whole minor
  /// units and sorted by code. Different currencies are never added.
  static Map<String, double> totalsByCurrency(Iterable<BillEntity> bills) {
    final byCode = <String, List<double>>{};
    for (final b in bills) {
      (byCode[b.currency] ??= []).add(b.amount);
    }
    final codes = byCode.keys.toList()..sort();
    return {
      for (final code in codes)
        code: () {
          final math = MoneyMath.forCurrency(code);
          return math.toAmount(math.sumUnits(byCode[code]!));
        }(),
    };
  }

  /// "2 bills · ₹2,499" under a group of the list: the count, then one
  /// total per currency, never added across currencies, and never adding
  /// paid bills to unpaid ones.
  ///
  /// A group whose name already says whether it is paid ([labelled] false:
  /// Overdue, Due soon, Later, Paid) shows its unpaid totals plainly, and a
  /// paid-only group just its count. A mixed group ([labelled] true:
  /// Recurring, Not linked) names each total: "₹649 unpaid · ₹300 paid".
  static String groupSummary(List<BillEntity> bills, {bool labelled = false}) {
    final n = bills.length;
    final unpaid = totalsByCurrency(bills.where((b) => !b.isPaid));
    final paid = labelled
        ? totalsByCurrency(bills.where((b) => b.isPaid))
        : const <String, double>{};
    String totals(Map<String, double> byCode, String suffix) => [
      for (final MapEntry(key: code, value: amount) in byCode.entries)
        '${AppMoney.format(amount, currency: code)}$suffix',
    ].join(' · ');
    return [
      '$n ${n == 1 ? 'bill' : 'bills'}',
      if (unpaid.isNotEmpty) totals(unpaid, labelled ? ' unpaid' : ''),
      if (paid.isNotEmpty) totals(paid, ' paid'),
    ].join(' · ');
  }

  /// Human-friendly due text, e.g. "Due tomorrow", "3 days overdue",
  /// "Due in 2 weeks", "Due 14 Oct".
  static String dueText(BillEntity bill) {
    if (bill.isPaid) {
      return bill.paidDate == null
          ? 'Paid'
          : 'Paid ${AppDates.day(bill.paidDate!)}';
    }
    final diff = calendarDaysBetween(DateTime.now(), bill.dueDate);
    if (diff < 0) {
      final d = -diff;
      return d == 1 ? '1 day overdue' : '$d days overdue';
    }
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 14) return 'Due in $diff days';
    if (diff < 60) return 'Due in ${(diff / 7).round()} weeks';
    return 'Due ${AppDates.day(bill.dueDate)}';
  }
}

/// One bill as a compact list row: category tile in its status colour, the
/// title, when it is due, who pays it, the amount and a quick pay action.
///
/// Paid/unpaid and due/overdue changes animate in place: the icon tint,
/// strike-through title, status icon and amount all ease to the new state,
/// while the due text itself stays fully readable throughout.
///
/// With [showBudgetLink], a third line says which budget the bill is paid
/// from ("Paid from October 2026") or "Not linked"; [budgetName] is that
/// budget's label, and the line is left out for a linked bill whose budget
/// name isn't known.
class BillCard extends StatelessWidget {
  final BillEntity bill;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;

  /// Tooltip and accessibility action for [onMarkPaid].
  final String markPaidLabel;

  /// Icon of the [onMarkPaid] button: a check for a plain "Mark as paid",
  /// the receipt for "Mark paid & record expense" (as on the bill's details
  /// and its confirmation), so the two actions never look the same.
  final IconData markPaidIcon;
  final bool showBudgetLink;
  final String? budgetName;

  const BillCard({
    super.key,
    required this.bill,
    this.onTap,
    this.onMarkPaid,
    this.markPaidLabel = 'Mark as paid',
    this.markPaidIcon = Icons.check_circle_outline_rounded,
    this.showBudgetLink = false,
    this.budgetName,
  });

  /// "Paid from {budget}", "Not linked", or null when not shown.
  String? get linkText {
    if (!showBudgetLink) return null;
    if (bill.budgetId == null) return 'Not linked';
    return budgetName == null ? null : 'Paid from $budgetName';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = bill.status;
    final color = BillVisuals.colorFor(context, status);
    final amount = AppMoney.format(bill.amount, currency: bill.currency);
    final dueText = BillVisuals.dueText(bill);
    final link = linkText;
    final linkSemantics = link == null
        ? ''
        : bill.budgetId == null
        ? ', not linked to a budget'
        : ', paid from $budgetName';
    final muted = bill.isPaid;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final large = AppSizes.isLargeText(context);
    final titleStyle = (theme.textTheme.titleSmall ?? const TextStyle())
        .copyWith(
          decoration: muted ? TextDecoration.lineThrough : TextDecoration.none,
          color: muted ? mutedColor : theme.colorScheme.onSurface,
        );
    final amountStyle = (theme.textTheme.titleSmall ?? const TextStyle())
        .copyWith(
          color: muted ? mutedColor : theme.colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final dueStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: color,
    );

    Widget scaleFade(Widget child, Animation<double> animation) =>
        ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );

    return Semantics(
      button: onTap != null,
      label: CurrencyFormatter.forSpeech(
        '${bill.title}, $amount, $dueText, '
        '${BillVisuals.statusLabel(status)}'
        '${bill.repeats ? ', repeats ${bill.recurrenceType.label.toLowerCase()}' : ''}'
        '$linkSemantics',
      ),
      onTap: onTap,
      // The card merges into one node, so the nested "Mark as paid"
      // button would be unreachable; expose it as a custom action.
      customSemanticsActions: onMarkPaid != null && !bill.isPaid
          ? {CustomSemanticsAction(label: markPaidLabel): onMarkPaid!}
          : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.listRowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                IconTile(
                  icon: BillVisuals.iconFor(bill.category),
                  color: color,
                  size: AppSizes.avatarSm,
                  animate: true,
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              curve: AppMotion.standardCurve,
                              style: titleStyle,
                              child: Text(
                                bill.title,
                                maxLines: large ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (bill.repeats) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              Icons.repeat_rounded,
                              size: AppSizes.inlineIcon(context),
                              color: mutedColor,
                              semanticLabel: 'Recurring',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          AnimatedSwitcher(
                            duration: duration,
                            switchInCurve: AppMotion.enter,
                            switchOutCurve: AppMotion.exit,
                            transitionBuilder: scaleFade,
                            child: Icon(
                              BillVisuals.statusIcon(status),
                              key: ValueKey(status),
                              size: AppSizes.inlineIcon(context),
                              color: color,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              curve: AppMotion.standardCurve,
                              style: dueStyle,
                              child: Text(
                                dueText,
                                maxLines: large ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (link != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            Icon(
                              bill.budgetId == null
                                  ? Icons.link_off_rounded
                                  : Icons.account_balance_wallet_outlined,
                              size: AppSizes.inlineIcon(context),
                              color: mutedColor,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                link,
                                maxLines: large ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: mutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (large) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppMoney(
                          amount: bill.amount,
                          currency: bill.currency,
                          color: amountStyle.color,
                        ),
                      ],
                    ],
                  ),
                ),
                // With large text the amount moves under the text above,
                // so the bill keeps room for its name and due date.
                if (!large) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.38,
                    ),
                    child: AppMoney(
                      amount: bill.amount,
                      currency: bill.currency,
                      textAlign: TextAlign.end,
                      color: amountStyle.color,
                    ),
                  ),
                ],
                AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: scaleFade,
                  child: onMarkPaid != null && !bill.isPaid
                      ? Padding(
                          key: const ValueKey('markPaid'),
                          padding: const EdgeInsetsDirectional.only(
                            start: AppSpacing.xs,
                          ),
                          child: IconButton(
                            tooltip: markPaidLabel,
                            onPressed: onMarkPaid,
                            icon: Icon(
                              markPaidIcon,
                              color: context.appColors.success,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('noAction')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
