import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';

/// A card widget displaying a single bill's summary information.
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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Category icon
              _CategoryIcon(category: bill.category, status: status),
              const SizedBox(width: AppSpacing.smd),
              // Title and due info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bill.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: bill.isPaid
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: bill.isPaid
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    )
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (bill.isRecurring) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.repeat_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _DueText(bill: bill),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Amount and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(
                      bill.amount,
                      code: bill.currency,
                      decimalDigits: 0,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: bill.isPaid
                          ? AppColors.success
                          : status == BillStatus.overdue
                          ? AppColors.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(status: status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final BillCategory category;
  final BillStatus status;

  const _CategoryIcon({required this.category, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == BillStatus.overdue
        ? AppColors.error
        : status == BillStatus.paid
        ? AppColors.success
        : AppColors.primary;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(_iconForCategory(category), color: color, size: 22),
    );
  }

  IconData _iconForCategory(BillCategory category) {
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
}

class _DueText extends StatelessWidget {
  final BillEntity bill;

  const _DueText({required this.bill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    final difference = due.difference(today).inDays;

    String text;
    Color color;

    if (bill.isPaid) {
      text = 'Paid';
      color = AppColors.success;
    } else if (bill.status == BillStatus.overdue) {
      final overdueDays = today.difference(due).inDays;
      text = overdueDays == 1 ? '1 day overdue' : '$overdueDays days overdue';
      color = AppColors.error;
    } else if (bill.status == BillStatus.dueToday) {
      text = 'Due today';
      color = AppColors.warning;
    } else if (difference == 1) {
      text = 'Due tomorrow';
      color = AppColors.primary;
    } else {
      text = 'Due in $difference days';
      color = AppColors.primary;
    }

    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BillStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case BillStatus.paid:
        return StatusChipStyles.healthy('Paid');
      case BillStatus.overdue:
        return StatusChipStyles.danger('Overdue');
      case BillStatus.dueToday:
        return StatusChipStyles.warning('Due Today');
      case BillStatus.upcoming:
        return StatusChipStyles.info('Upcoming');
    }
  }
}
