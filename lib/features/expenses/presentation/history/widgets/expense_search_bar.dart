import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';

/// Animated search bar for the expense history screen.
///
/// Debounces input via the parent, but exposes the raw text changes here.
class ExpenseSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const ExpenseSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: TextField(
        key: const Key('expenseSearchBar'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by note, category, or tag...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                key: const Key('expenseSearchClear'),
                icon: const Icon(Icons.close),
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onClear();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
