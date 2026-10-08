@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/theme/app_tone.dart';
import 'package:monivo/core/theme/app_typography.dart';
import 'package:monivo/core/widgets/app_card.dart';
import 'package:monivo/core/widgets/app_list.dart';
import 'package:monivo/core/widgets/app_metric.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/widgets/app_section.dart';
import 'package:monivo/core/widgets/app_track.dart';
import 'package:monivo/core/widgets/status_chip.dart';

import 'golden_harness.dart';

/// A specimen of the Phase 2 design system: money roles, status tones, a
/// track with a marker, metrics and a flat list section, with real figures
/// from the sample budget.
class _Specimen extends StatelessWidget {
  const _Specimen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final caution = context.tone(AppTone.caution);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            Text(
              'Good afternoon',
              style: context.appTypography.eyebrow.copyWith(color: muted),
            ),
            Text('October Household', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Today's Safe Spending",
              style: theme.textTheme.titleSmall?.copyWith(color: muted),
            ),
            const AppMoney(
              amount: 867.625,
              currency: 'INR',
              role: MoneyRole.hero,
              floored: true,
              split: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusChip.tone(
                  label: 'On track',
                  tone: AppTone.positive,
                  icon: Icons.check_circle_rounded,
                ),
                StatusChip.tone(
                  label: 'At risk',
                  tone: AppTone.caution,
                  icon: Icons.trending_down_rounded,
                ),
                StatusChip.tone(
                  label: 'Over budget',
                  tone: AppTone.critical,
                  icon: Icons.remove_circle_rounded,
                ),
                StatusChip.tone(
                  label: 'Due soon',
                  tone: AppTone.info,
                  icon: Icons.schedule_rounded,
                ),
                StatusChip.tone(
                  label: 'Not started',
                  tone: AppTone.neutral,
                  icon: Icons.event_busy_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTrack(
              value: 570 / 867.62,
              color: caution.accent,
              markers: [TrackMarker(position: 8 / 31, color: muted)],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: [
                Expanded(
                  child: AppMetric(
                    label: 'Spent today',
                    value: AppMoney(amount: 570, currency: 'INR'),
                  ),
                ),
                Expanded(
                  child: AppMetric(
                    label: 'Left today',
                    alignEnd: true,
                    value: AppMoney(
                      amount: 297.625,
                      currency: 'INR',
                      floored: true,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppMoney(
              amount: 34897,
              currency: 'INR',
              role: MoneyRole.display,
            ),
            const AppMoney(
              amount: 20253,
              currency: 'INR',
              role: MoneyRole.title,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSection(
              title: 'Recent',
              action: TextButton(
                onPressed: () {},
                child: const Text('See all'),
              ),
              child: AppGroupedList(
                dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                children: [
                  AppListRow(
                    leading: IconTile(
                      icon: Icons.restaurant_rounded,
                      color: theme.colorScheme.error,
                      size: AppSizes.avatarSm,
                    ),
                    title: 'Lunch',
                    subtitle: 'Food · 12:40 PM',
                    trailing: const AppMoney(amount: 390, currency: 'INR'),
                    onTap: () {},
                  ),
                  AppListRow(
                    leading: IconTile(
                      icon: Icons.shopping_bag_rounded,
                      color: theme.colorScheme.tertiary,
                      size: AppSizes.avatarSm,
                    ),
                    title: 'Birthday gift for Ananya',
                    subtitle: 'Shopping · Yesterday',
                    trailing: const AppMoney(amount: 2200, currency: 'INR'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: () {}, child: const Text('Add expense')),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'design system specimen',
    (tester) => expectGoldenMatrix(tester, 'design_system', const _Specimen()),
    skip: goldenSkip,
  );
}
