import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/currency_entity.dart';

/// Picker allowing the user to search and select an application currency.
///
/// Designed to sit inside a bottom sheet: the list is capped to a share of
/// the screen height and scrolls internally.
class CurrencySelector extends StatefulWidget {
  final String selectedCode;
  final ValueChanged<CurrencyEntity> onSelected;

  const CurrencySelector({
    super.key,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  String _query = '';

  List<CurrencyEntity> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return availableCurrencies;
    return availableCurrencies
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              c.symbol.contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search by name or code',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: filtered.isEmpty
              ? Padding(
                  padding: AppSpacing.paddingLg,
                  child: Text(
                    'No currency matches "${_query.trim()}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final currency = filtered[index];
                    final selected = currency.code == widget.selectedCode;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      leading: Container(
                        width: AppSizes.avatarMd,
                        height: AppSizes.avatarMd,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          currency.symbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      title: Text(
                        currency.name,
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(currency.code),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        widget.onSelected(currency);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
