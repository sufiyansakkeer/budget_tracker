import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import 'onboarding_step_layout.dart';

/// A single-date picker step used for both the budget start and end date
/// during onboarding.
class BudgetDateStepWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime date;
  final String? errorMessage;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const BudgetDateStepWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    this.errorMessage,
    required this.onDateChanged,
    required this.onContinue,
    required this.onBack,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = DateTime(date.year, date.month, date.day) == today;
    final hasError = errorMessage != null;

    return OnboardingStepLayout(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      footer: OnboardingContinueButton(
        buttonKey: const Key('dateStepContinueButton'),
        onPressed: hasError ? null : onContinue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label:
                'Selected date ${DateFormat('d MMMM yyyy').format(date)}. '
                'Tap to change',
            onTap: () => _pickDate(context),
            excludeSemantics: true,
            child: AppCard(
              onTap: () => _pickDate(context),
              child: Row(
                children: [
                  IconTile(
                    icon: Icons.calendar_month_rounded,
                    color: hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          DateFormat('d MMMM yyyy').format(date),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  if (isToday)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Text(
                        'Today',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.edit_calendar_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (hasError) FormFieldError(message: errorMessage!),
        ],
      ),
    );
  }
}
