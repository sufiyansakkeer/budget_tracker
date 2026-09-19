import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_state.dart';
import 'onboarding_step_layout.dart';

class CurrencyStepWidget extends StatefulWidget {
  final CurrencyItem selectedCurrency;
  final ValueChanged<CurrencyItem> onSelected;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const CurrencyStepWidget({
    super.key,
    required this.selectedCurrency,
    required this.onSelected,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<CurrencyStepWidget> createState() => _CurrencyStepWidgetState();
}

class _CurrencyStepWidgetState extends State<CurrencyStepWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<CurrencyItem> _filtered = availableCurrencies;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? availableCurrencies
          : availableCurrencies.where((c) {
              return c.code.toLowerCase().contains(query) ||
                  c.name.toLowerCase().contains(query) ||
                  c.symbol.contains(query);
            }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OnboardingStepLayout(
      title: 'Which currency do you use?',
      subtitle: 'Amounts in this budget are shown in this currency.',
      onBack: widget.onBack,
      scrollable: false,
      footer: OnboardingContinueButton(onPressed: widget.onContinue),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by code or name',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _searchController.clear,
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No currency matches "${_searchController.text.trim()}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final currency = _filtered[index];
                      final isSelected =
                          currency.code == widget.selectedCurrency.code;
                      return ListTile(
                        onTap: () => widget.onSelected(currency),
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                        leading: Container(
                          width: AppSizes.avatarMd,
                          height: AppSizes.avatarMd,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            currency.symbol,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isSelected
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
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
