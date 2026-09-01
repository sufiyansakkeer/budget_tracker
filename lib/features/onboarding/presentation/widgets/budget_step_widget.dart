import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';

class BudgetStepWidget extends StatefulWidget {
  final String initialValue;
  final String currencySymbol;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const BudgetStepWidget({
    super.key,
    required this.initialValue,
    required this.currencySymbol,
    this.errorMessage,
    required this.onChanged,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<BudgetStepWidget> createState() => _BudgetStepWidgetState();
}

class _BudgetStepWidgetState extends State<BudgetStepWidget> {
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
  Widget build(BuildContext themeContext) {
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
            'What is your budget amount?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Set the total amount for this budget period.',
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
                    child: Text(
                      widget.currencySymbol,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: context.appColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      key: const Key('monthlyBudgetTextField'),
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      autofocus: true,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: '30,000',
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
              key: const Key('budgetStepContinueButton'),
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
