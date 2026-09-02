import 'package:flutter/material.dart';

import '../../domain/entities/currency_entity.dart';

/// Picker allowing the user to search and select an application currency.
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
              c.code.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search currencies...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final currency = _filtered[index];
              final selected = currency.code == widget.selectedCode;
              return ListTile(
                leading: Text(
                  currency.symbol,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                title: Text(currency.name),
                subtitle: Text(currency.code),
                trailing: selected
                    ? Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.secondary,
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
