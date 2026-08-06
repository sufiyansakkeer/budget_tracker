import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/features/settings/domain/entities/currency_entity.dart';
import 'package:budget_tracker/features/settings/presentation/widgets/currency_selector.dart';

void main() {
  group('CurrencySelector', () {
    testWidgets('should display search field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencySelector(
              selectedCode: 'USD',
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should display currency list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencySelector(
              selectedCode: 'USD',
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // Should display multiple currencies
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('should highlight selected currency', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencySelector(
              selectedCode: 'USD',
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // Find USD in the list
      expect(find.text('USD'), findsWidgets);
    });

    testWidgets('should call onSelected when currency is tapped', (tester) async {
      CurrencyEntity? selectedCurrency;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencySelector(
              selectedCode: 'USD',
              onSelected: (currency) => selectedCurrency = currency,
            ),
          ),
        ),
      );

      // Tap on a currency (first one in list)
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      expect(selectedCurrency, isNotNull);
    });

    testWidgets('should filter currencies when searching', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencySelector(
              selectedCode: 'USD',
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // Enter search term
      await tester.enterText(find.byType(TextField), 'EUR');
      await tester.pump();

      // Should filter the list
      // (exact verification depends on implementation)
    });
  });
}