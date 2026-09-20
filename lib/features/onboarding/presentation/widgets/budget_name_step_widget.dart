import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import 'onboarding_step_layout.dart';

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
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  static const _suggestions = ['Personal', 'Household', 'Vacation', 'Wedding'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid =>
      widget.errorMessage == null && _controller.text.trim().isNotEmpty;

  void _apply(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    widget.onChanged(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OnboardingStepLayout(
      title: 'What is your budget called?',
      subtitle:
          'Give your first budget a name. You can add more budgets '
          'later.',
      onBack: widget.onBack,
      footer: OnboardingContinueButton(
        buttonKey: const Key('budgetNameContinueButton'),
        onPressed: _isValid ? widget.onContinue : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('budgetNameTextField'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: theme.textTheme.titleLarge,
            decoration: InputDecoration(
              labelText: 'Budget name',
              hintText: 'e.g. Personal',
              prefixIcon: const Icon(Icons.label_outline_rounded),
              errorText: widget.errorMessage,
            ),
            onChanged: (val) {
              widget.onChanged(val);
              setState(() {});
            },
            onSubmitted: (_) {
              if (_isValid) widget.onContinue();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in _suggestions)
                ActionChip(label: Text(s), onPressed: () => _apply(s)),
            ],
          ),
        ],
      ),
    );
  }
}
