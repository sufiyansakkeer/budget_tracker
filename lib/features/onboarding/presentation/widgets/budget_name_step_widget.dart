import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';

class BudgetNameStepWidget extends StatefulWidget {
  final String initialValue;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const BudgetNameStepWidget({
    super.key,
    required this.initialValue,
    this.errorMessage,
    required this.onChanged,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<BudgetNameStepWidget> createState() => _BudgetNameStepWidgetState();
}

class _BudgetNameStepWidgetState extends State<BudgetNameStepWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid =
        widget.errorMessage == null && _controller.text.trim().isNotEmpty;

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
            'What is your budget called?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Give your budget a name, e.g. Personal, Vacation, Business.',
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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: context.appColors.primary,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      key: const Key('budgetNameTextField'),
                      controller: _controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Personal',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      onChanged: (val) {
                        widget.onChanged(val);
                        setState(() {});
                      },
                    ),
                  ),
                ],
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
              key: const Key('budgetNameContinueButton'),
              onPressed: isValid ? widget.onContinue : null,
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
