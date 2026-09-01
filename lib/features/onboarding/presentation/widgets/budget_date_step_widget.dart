import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// A single-date picker step used for both the budget start and end date
/// during onboarding. Renders a prominent date tile and a date picker.
class BudgetDateStepWidget extends StatefulWidget {
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

  @override
  State<BudgetDateStepWidget> createState() => _BudgetDateStepWidgetState();
}

class _BudgetDateStepWidgetState extends State<BudgetDateStepWidget> {
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      widget.onDateChanged(picked);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            widget.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: AppSpacing.xxl),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: widget.errorMessage != null
                    ? context.appColors.error
                    : context.appColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickDate,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.appColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: context.appColors.primary,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected date',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatDate(widget.date),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_calendar_rounded),
                  ],
                ),
              ),
            ),
          ),
          if (widget.errorMessage != null) ...[
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: context.appColors.error,
                  size: 18,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.errorMessage!,
                    style: TextStyle(
                      color: context.appColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              key: const Key('dateStepContinueButton'),
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
