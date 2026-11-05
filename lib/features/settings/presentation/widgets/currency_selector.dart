import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../domain/entities/currency_entity.dart';

/// The app's one currency picker (UX-110): a searchable list of currencies.
///
/// Open it with [show], which puts it in a bottom sheet under a header and
/// returns the chosen currency. Tapping a currency closes that sheet itself,
/// so a caller must never pop again: that would close the screen beneath
/// too. The list is capped to a share of the screen height and scrolls
/// internally.
class CurrencySelector extends StatefulWidget {
  final String selectedCode;

  /// Called with the tapped currency, just before the sheet closes with it.
  final ValueChanged<CurrencyEntity>? onSelected;

  /// The currencies to offer. Defaults to the app's settings currencies; the
  /// currency converter passes every currency its rate provider supports.
  final List<CurrencyEntity> currencies;

  const CurrencySelector({
    super.key,
    required this.selectedCode,
    this.onSelected,
    this.currencies = availableCurrencies,
  });

  /// Shows the picker in a bottom sheet titled [title] and returns the
  /// chosen currency, or null when it was closed without one.
  static Future<CurrencyEntity?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String? selectedCode,
    List<CurrencyEntity> currencies = availableCurrencies,
  }) => AppBottomSheet.show<CurrencyEntity>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetHeader(title: title, subtitle: subtitle),
        CurrencySelector(
          selectedCode: selectedCode ?? '',
          currencies: currencies,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  String _query = '';

  List<CurrencyEntity> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.currencies;
    return widget.currencies
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
                    return CurrencyListTile(
                      currency: currency,
                      selected: currency.code == widget.selectedCode,
                      onTap: () {
                        widget.onSelected?.call(currency);
                        // Closes the sheet this picker is in, with the pick.
                        Navigator.of(context).pop(currency);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One currency in a list: its symbol in a circle, name and code, and a
/// check mark when [selected]. The picker's row, and onboarding's.
class CurrencyListTile extends StatelessWidget {
  final CurrencyEntity currency;
  final bool selected;
  final VoidCallback onTap;

  const CurrencyListTile({
    super.key,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.5,
      ),
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
        padding: const EdgeInsets.all(AppSpacing.xs),
        // Some symbols are several characters ("oz t").
        child: FittedBox(
          child: Text(
            currency.symbol,
            style: theme.textTheme.titleMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
      title: Text(currency.name, style: theme.textTheme.titleSmall),
      subtitle: Text(currency.code),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
    );
  }
}

/// The currency beside an amount, in a field's frame: its code, and a tap
/// that opens [CurrencySelector.show]. [value] is null when none of
/// [currencies] is chosen (an unknown saved code).
class CurrencyPickerField extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final List<CurrencyEntity> currencies;

  /// The sheet's subtitle: what the currency applies to.
  final String? sheetSubtitle;

  const CurrencyPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.currencies = availableCurrencies,
    this.sheetSubtitle,
  });

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await CurrencySelector.show(
      context,
      title: 'Currency',
      subtitle: sheetSubtitle,
      selectedCode: value,
      currencies: currencies,
    );
    if (picked != null && picked.code != value) onChanged(picked.code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // At least as wide as a code and its arrow, wider at large text sizes
    // rather than clipping the code.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 112),
      child: IntrinsicWidth(
        child: Semantics(
          button: true,
          label: 'Currency',
          value: value ?? 'Not chosen',
          hint: 'Change currency',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: AppSpacing.borderRadiusSm,
            child: InputDecorator(
              isEmpty: value == null,
              decoration: const InputDecoration(
                labelText: 'Currency',
                suffixIcon: Icon(Icons.expand_more_rounded),
              ),
              // The amount's size, so the two fields line up.
              child: Text(
                value ?? '',
                style: theme.textTheme.titleLarge,
                softWrap: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
