import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_motion.dart';

/// Search field for the expense history screen.
///
/// Debounces input via the bloc; this widget only reports raw changes.
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: TextField(
        key: const Key('expenseSearchBar'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search notes, categories or tags',
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return AnimatedSwitcher(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.fast,
                ),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: value.text.isEmpty
                    ? const SizedBox.shrink(key: ValueKey('noClear'))
                    : IconButton(
                        key: const Key('expenseSearchClear'),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear search',
                        onPressed: () {
                          controller.clear();
                          onClear();
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
