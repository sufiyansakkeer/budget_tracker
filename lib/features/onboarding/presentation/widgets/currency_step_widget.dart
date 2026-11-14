import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../../settings/presentation/widgets/currency_selector.dart';
import 'onboarding_step_layout.dart';

class CurrencyStepWidget extends StatefulWidget {
  final CurrencyEntity selectedCurrency;
  final ValueChanged<CurrencyEntity> onSelected;
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
  List<CurrencyEntity> _filtered = availableCurrencies;

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
                      return CurrencyListTile(
                        currency: currency,
                        selected: currency.code == widget.selectedCurrency.code,
                        onTap: () => widget.onSelected(currency),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
