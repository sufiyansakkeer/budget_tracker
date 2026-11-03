import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import '../../domain/entities/pay_later_tab.dart';
import 'tab_visuals.dart';

/// Which tab a "Pay later" purchase goes on (spec §7, Add/Edit Expense).
///
/// Lists the tabs that aren't archived, plus [keepTabId] (the tab an edited
/// purchase is already on) even when archived. Tabs in a currency other
/// than [currency] (the selected budget's) are listed disabled with the
/// reason. With no tab to list it offers "Create your first tab"; otherwise
/// "New tab" sits under the list.
class TabSelector extends StatelessWidget {
  /// Every tab, archived included; null while loading.
  final List<PayLaterTab>? tabs;

  /// The tabs couldn't be read.
  final bool failed;
  final VoidCallback onRetry;

  /// The selected budget's currency; null when not known yet.
  final String? currency;
  final String? selectedTabId;
  final String? keepTabId;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreateTab;
  final String? errorText;

  const TabSelector({
    super.key,
    required this.tabs,
    required this.failed,
    required this.onRetry,
    required this.currency,
    required this.selectedTabId,
    required this.onSelected,
    required this.onCreateTab,
    this.keepTabId,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final all = tabs;
    final Widget body;
    if (failed) {
      body = StatusCard(
        color: theme.colorScheme.error,
        icon: Icons.error_outline_rounded,
        message: "Couldn't load your tabs.",
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      );
    } else if (all == null) {
      body = Semantics(
        label: 'Loading tabs',
        excludeSemantics: true,
        child: Shimmer(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final w in [112.0, 96.0])
                SkeletonBox(width: w, height: 32, radius: AppSpacing.radiusSm),
            ],
          ),
        ),
      );
    } else {
      final shown = [
        for (final tab in all)
          if (!tab.isArchived || tab.id == keepTabId) tab,
      ];
      body = shown.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A tab keeps track of what you owe a place that lets you '
                  'pay later.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonalIcon(
                  key: const Key('createFirstTabButton'),
                  onPressed: onCreateTab,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create your first tab'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [for (final tab in shown) _chip(tab)],
                ),
                TextButton.icon(
                  key: const Key('newTabButton'),
                  onPressed: onCreateTab,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New tab'),
                ),
              ],
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tab', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        body,
        if (errorText != null) FormFieldError(message: errorText!),
      ],
    );
  }

  Widget _chip(PayLaterTab tab) {
    final fits = currency == null || tab.currency == currency;
    return ChoiceChip(
      key: Key('tab_${tab.id}'),
      selected: tab.id == selectedTabId,
      showCheckmark: false,
      avatar: Icon(tabCategoryIcon(tab.category), size: AppSizes.iconSm + 2),
      label: Text(fits ? tab.name : '${tab.name} · In ${tab.currency}'),
      onSelected: fits ? (_) => onSelected(tab.id) : null,
    );
  }
}
