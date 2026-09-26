import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import 'onboarding_step_layout.dart';

class WelcomeStepWidget extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeStepWidget({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Container(
                  width: AppSizes.avatarXl,
                  height: AppSizes.avatarXl,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: AppSpacing.borderRadiusXl,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: AppSizes.iconHero,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome to Monivo',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Know what you can safely spend today, every day.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _Point(
                  icon: Icons.event_note_rounded,
                  title: 'Budgets with their own dates',
                  body:
                      'A month, a trip, a wedding: each budget has its own '
                      'amount and period.',
                ),
                const _Point(
                  icon: Icons.today_rounded,
                  title: "Today's Safe Spending",
                  body:
                      'What is left is spread over the remaining days, so '
                      'you always know what today can hold.',
                ),
                const _Point(
                  icon: Icons.lock_outline_rounded,
                  title: 'Private by design',
                  body: 'Everything stays on your device.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: OnboardingContinueButton(
            label: 'Get started',
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Point({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: icon,
            color: theme.colorScheme.primary,
            size: AppSizes.avatarSm,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
