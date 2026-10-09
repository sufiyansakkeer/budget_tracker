@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/widgets/app_money.dart';

import 'golden_harness.dart';

/// OMR amounts as Home draws them: the hero figure, metrics and a sentence,
/// with the Central Bank of Oman's sign (U+20C4) from the bundled font,
/// to the left of the figures with a space, at their height.
class _OmaniRial extends StatelessWidget {
  const _OmaniRial();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            Text("Today's Safe Spending", style: theme.textTheme.titleSmall),
            const AppMoney(
              amount: 852.34,
              currency: 'OMR',
              role: MoneyRole.hero,
              floored: true,
              split: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(
              children: [
                Expanded(child: AppMoney(amount: 12.345, currency: 'OMR')),
                AppMoney(
                  amount: 4420.879,
                  currency: 'OMR',
                  role: MoneyRole.title,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${CurrencyFormatter.format(97518.587, code: 'OMR')} left of '
              '${CurrencyFormatter.format(98765.432, code: 'OMR')}',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              'Bills and money set aside are '
              '${CurrencyFormatter.format(250, code: 'AED')} more than '
              "what's left in this budget.",
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Omani rial sign', (tester) async {
    await expectGoldenMatrix(
      tester,
      'omani_rial',
      const _OmaniRial(),
      size: const Size(360, 420),
    );
  }, skip: goldenSkip);
}
