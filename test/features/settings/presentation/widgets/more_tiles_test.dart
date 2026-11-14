import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_overview.dart';
import 'package:monivo/features/settings/presentation/widgets/more_tiles.dart';

void main() {
  final today = DateTime(2026, 10, 8);

  BillEntity bill(String id, DateTime due, {bool paid = false}) => BillEntity(
    id: id,
    title: id,
    amount: 100,
    currency: 'INR',
    category: BillCategory.utilities,
    dueDate: due,
    isPaid: paid,
    createdAt: today,
    updatedAt: today,
  );

  BudgetEntity budget(String id, DateTime start, DateTime end) => BudgetEntity(
    id: id,
    name: id,
    monthlyAmount: 1000,
    remainingAmount: 1000,
    currency: 'INR',
    startDate: start,
    endDate: end,
    createdAt: start,
    updatedAt: start,
  );

  group('MoreTileValues.from', () {
    test('bills: overdue first, then due within a week', () {
      final v = MoreTileValues.from(
        today: today,
        bills: [
          bill('late', DateTime(2026, 10, 2)),
          bill('soon', DateTime(2026, 10, 12)),
          bill('today', today),
          bill('later', DateTime(2026, 10, 30)),
          bill('paid', DateTime(2026, 10, 1), paid: true),
        ],
      );
      expect(v.bills, '1 overdue · 2 due soon');
    });

    test('bills: nothing due this week, or none read', () {
      expect(
        MoreTileValues.from(today: today, bills: const []).bills,
        'Nothing due soon',
      );
      expect(
        MoreTileValues.from(today: today).bills,
        MoreTileValues.fallback.bills,
      );
    });

    test('pay later: what is owed, and whether any is overdue', () {
      PayLaterOverview overview(List<CurrencyTotals> totals) =>
          PayLaterOverview(
            totals: totals,
            tabs: const [],
            activeTabCount: 1,
            upcoming: const [],
            recentPurchases: const [],
            recentPayments: const [],
            today: today,
          );
      expect(
        MoreTileValues.from(
          today: today,
          payLater: overview(const [
            CurrencyTotals(
              currency: 'INR',
              owed: 3460,
              overdue: 600,
              addedThisMonth: 0,
              paidThisMonth: 0,
            ),
          ]),
        ).payLater,
        '₹3,460 owed · 1 overdue',
      );
      expect(
        MoreTileValues.from(
          today: today,
          payLater: overview(const []),
        ).payLater,
        'Nothing owed',
      );
    });

    test('budgets: running today and starting later', () {
      final v = MoreTileValues.from(
        today: today,
        budgets: [
          budget('oct', DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
          budget('trip', DateTime(2026, 11, 14), DateTime(2026, 11, 24)),
          budget('sep', DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        ],
      );
      expect(v.budgets, '1 running · 1 later');
    });

    test('categories: how many', () {
      expect(
        MoreTileValues.from(today: today, categoryCount: 13).categories,
        '13 in use',
      );
    });
  });

  testWidgets('six tiles that open their screens', (tester) async {
    var dataTaps = 0;
    final router = GoRouter(
      initialLocation: '/more',
      routes: [
        GoRoute(
          path: '/more',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: MoreTiles(
                load: () async => MoreTileValues.from(
                  today: today,
                  bills: const [],
                  categoryCount: 13,
                ),
                onData: () => dataTaps++,
              ),
            ),
          ),
        ),
        for (final path in [
          '/app/bills',
          '/app/pay-later',
          '/app/categories',
          '/app/settings/converter',
          '/app/budgets/all',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('page $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing due soon'), findsOneWidget);
    expect(find.text('13 in use'), findsOneWidget);

    await tester.tap(find.text('Your data'));
    expect(dataTaps, 1);

    for (final (title, path) in const [
      ('Bills', '/app/bills'),
      ('Pay later', '/app/pay-later'),
      ('Categories', '/app/categories'),
      ('Currency converter', '/app/settings/converter'),
      ('All budgets', '/app/budgets/all'),
    ]) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text('page $path'), findsOneWidget, reason: title);
      router.pop();
      await tester.pumpAndSettle();
    }
  });
}
