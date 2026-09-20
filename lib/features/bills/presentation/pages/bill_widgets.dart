import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';

/// Shared icon / status mapping for bills so the list, details and dashboard
/// always draw a bill the same way.
class BillVisuals {
  BillVisuals._();

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

  /// Chip combining icon + label + colour for a status.
  static StatusChip chip(BuildContext context, BillStatus status) => StatusChip(
    label: statusLabel(status),
    color: colorFor(context, status),
    icon: statusIcon(status),
  );

  /// Human-friendly due text, e.g. "Due tomorrow", "3 days overdue",
  /// "Due in 2 weeks", "Due 14 Oct".
  static String dueText(BillEntity bill) {
    if (bill.isPaid) {
      return bill.paidDate == null
          ? 'Paid'
          : 'Paid ${DateFormat('d MMM').format(bill.paidDate!)}';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    final diff = due.difference(today).inDays;
    if (diff < 0) {
      final d = -diff;
      return d == 1 ? '1 day overdue' : '$d days overdue';
    }
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 14) return 'Due in $diff days';
    if (diff < 60) return 'Due in ${(diff / 7).round()} weeks';
    return 'Due ${DateFormat('d MMM').format(due)}';
  }
}

/// A card widget displaying a single bill's summary information.
///
/// Paid/unpaid and due/overdue changes animate in place: the icon tint,
/// strike-through title, status icon and amount all ease to the new state,
/// while the due text itself stays fully readable throughout.
class BillCard extends StatelessWidget {
  final BillEntity bill;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;

  const BillCard({
    super.key,
    required this.bill,
    this.currency = '',
    this.onTap,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = bill.status;
    final color = BillVisuals.colorFor(context, status);
    final amount = CurrencyFormatter.format(
      bill.amount,
      code: bill.currency.isNotEmpty ? bill.currency : currency,
      decimalDigits: 0,
    );
    final dueText = BillVisuals.dueText(bill);
    final muted = bill.isPaid;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    final mutedColor = theme.colorScheme.onSurfaceVariant;
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
      label:
          '${bill.title}, $amount, $dueText, '
          '${BillVisuals.statusLabel(status)}'
          '${bill.isRecurring ? ', repeats ${bill.recurrenceType.label.toLowerCase()}' : ''}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              IconTile(
                icon: BillVisuals.iconFor(bill.category),
                color: color,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (bill.isRecurring) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.repeat_rounded,
                            size: AppSizes.iconXs,
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
                            size: AppSizes.iconXs,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppMotion.standardCurve,
                style: amountStyle,
                child: Text(amount),
              ),
              AnimatedSwitcher(
                duration: duration,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: scaleFade,
                child: onMarkPaid != null && !bill.isPaid
                    ? Padding(
                        key: const ValueKey('markPaid'),
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: IconButton(
                          tooltip: 'Mark as paid',
                          onPressed: onMarkPaid,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.check_circle_outline_rounded,
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
    );
  }
}
