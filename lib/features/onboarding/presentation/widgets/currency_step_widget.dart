import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_state.dart';
import '../../../../core/theme/app_colors_extension.dart';

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
  List<CurrencyItem> _filteredCurrencies = availableCurrencies;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = availableCurrencies;
      } else {
        _filteredCurrencies = availableCurrencies.where((c) {
          return c.code.toLowerCase().contains(query) ||
              c.name.toLowerCase().contains(query) ||
              c.symbol.contains(query);
        }).toList();
      }
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
            'Select your currency',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Choose the primary currency for your budget tracking.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search currency (e.g. INR, USD, Euro)',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredCurrencies.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final currency = _filteredCurrencies[index];
                final isSelected =
                    currency.code == widget.selectedCurrency.code;

                return InkWell(
                  onTap: () => widget.onSelected(currency),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.appColors.primary.withValues(alpha: 0.12)
                          : theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? context.appColors.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.appColors.primary
                                : theme.colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            currency.symbol,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : context.appColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currency.code,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: context.appColors.primary,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onContinue,
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
