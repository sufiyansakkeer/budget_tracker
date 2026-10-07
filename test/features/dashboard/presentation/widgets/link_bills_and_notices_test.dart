import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_linkable_bills_usecase.dart';
import 'package:monivo/features/dashboard/presentation/widgets/link_bills_sheet.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_notices.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('SafeToSpendNotices', () {
    testWidgets('renders nothing when every bill is included', (tester) async {
      final entity = safeToSpend();
      expect(SafeToSpendNotices.hasNotices(entity), isFalse);
      await tester.pumpWidget(wrap(SafeToSpendNotices(safeToSpend: entity)));

      expect(find.text('Bills not linked'), findsNothing);
      expect(find.text('Bills not included'), findsNothing);
    });

    testWidgets('not-linked bills offer "Link bills"', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        wrap(
          SafeToSpendNotices(
            safeToSpend: safeToSpend(
              unlinked: const UnlinkedCommitmentSummary(count: 2, total: 1500),
            ),
            onLinkBills: () => opened++,
          ),
        ),
      );

      expect(find.text('Bills not linked'), findsOneWidget);
      expect(
        find.text(
          "2 upcoming bills (₹1,500) aren't linked to a budget, so nothing "
          'is set aside for them.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Link bills'));
      expect(opened, 1);
    });

    testWidgets('unavailable bills offer a retry; other currencies are '
        'disclosed', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        wrap(
          SafeToSpendNotices(
            safeToSpend: safeToSpend(
              billsUnavailable: true,
              currencyExcluded: const CurrencyExcludedSummary(
                count: 1,
                totalsByCurrency: {'USD': 40},
              ),
            ),
            onRetry: () => retried++,
          ),
        ),
      );

      expect(find.text('Bills not included'), findsOneWidget);
      expect(
        find.text(
          "1 linked bill in USD isn't included because this budget uses INR.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });
  });

  group('LinkBillsSheetContent', () {
    final aug = BudgetEntity(
      id: 'aug',
      name: 'August 2026',
      monthlyAmount: 30000,
      remainingAmount: 30000,
      currency: 'INR',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    BillEntity bill(String id, String currency, double amount) => BillEntity(
      id: id,
      title: id,
      amount: amount,
      currency: currency,
      category: BillCategory.utilities,
      dueDate: DateTime(2026, 8, 20),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final data = LinkableBills(
      budget: aug,
      linkable: [bill('Water', 'INR', 300), bill('Phone', 'INR', 499.5)],
      otherCurrency: [bill('Cloud', 'USD', 9)],
    );

    Future<List<String>?> openSheet(
      WidgetTester tester,
      Future<void> Function() interact,
    ) async {
      List<String>? popped;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await showModalBottomSheet<List<String>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LinkBillsSheetContent(bills: data),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await interact();
      await tester.pumpAndSettle();
      return popped;
    }

    testWidgets('lists linkable bills selected, other currencies disabled', (
      tester,
    ) async {
      final popped = await openSheet(tester, () async {
        expect(find.text('Link bills to August 2026'), findsOneWidget);
        expect(find.text('Due 20 Aug · ₹300'), findsOneWidget);
        expect(find.text('Due 20 Aug · ₹499.50'), findsOneWidget);
        expect(find.text('In USD · this budget uses INR'), findsOneWidget);
        final cloud = tester.widget<CheckboxListTile>(
          find.byKey(const ValueKey('link_Cloud')),
        );
        expect(cloud.onChanged, isNull);
        expect(cloud.value, isFalse);

        // Deselect one, then link the other.
        await tester.tap(find.byKey(const ValueKey('link_Phone')));
        await tester.pump();
        await tester.tap(find.text('Link 1 bill'));
      });

      expect(popped, ['Water']);
    });

    testWidgets('nothing selected cannot be submitted', (tester) async {
      await openSheet(tester, () async {
        await tester.tap(find.byKey(const ValueKey('link_Water')));
        await tester.tap(find.byKey(const ValueKey('link_Phone')));
        await tester.pump();
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Select bills to link'),
        );
        expect(button.onPressed, isNull);
      });
    });
  });
}
