import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/presentation/pages/bill_widgets.dart';
import 'dashboard_info.dart';

/// "Upcoming bills" section: the next unpaid bills, each tappable, with a
/// compact empty state so Bills stays discoverable even when there are none.
class UpcomingBillsSection extends StatelessWidget {
  final List<BillEntity> bills;

  const UpcomingBillsSection({super.key, required this.bills});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Upcoming bills',
          infoContent: DashboardInfo.upcomingBills,
          trailing: TextButton(
            onPressed: () => context.push('/app/bills'),
            child: const Text('View all'),
          ),
        ),
        if (bills.isEmpty)
          EmptyState.compact(
            icon: Icons.event_available_rounded,
            title: 'No bills due soon',
            message:
                'Add recurring bills to get reminders before they are due.',
            actionLabel: 'Add bill',
            actionIcon: Icons.add_rounded,
            onAction: () => context.push('/app/bills/add'),
          )
        else
          for (var i = 0; i < bills.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: BillCard(
                  bill: bills[i],
                  onTap: () => context.push('/app/bills/${bills[i].id}'),
                ),
              ),
            ),
      ],
    );
  }
}
