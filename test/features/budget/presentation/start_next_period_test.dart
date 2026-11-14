import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/primary_button.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/presentation/pages/budget_form_screen.dart';
import 'package:monivo/features/budget/presentation/start_next_period.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';

import '../../../helpers/bill_ui_fakes.dart';
import '../../../helpers/pay_later_fakes.dart';
import 'pages/budget_form_screen_test.dart' show FakeSettingsRepository;

BudgetEntity _budget({
  required DateTime start,
  required DateTime end,
  String id = 'oct',
  String name = 'Household',
}) => BudgetEntity(
  id: id,
  name: name,
  monthlyAmount: 750.5,
  remainingAmount: 100,
  currency: 'OMR',
  startDate: start,
  endDate: end,
  reservedAmount: 50,
  savingsTarget: 25.25,
  icon: 'home',
  color: '#4CAF50',
  createdAt: start,
  updatedAt: start,
);

void main() {
  group('StartNextPeriod.datesAfter', () {
    ({DateTime start, DateTime end}) after(DateTime start, DateTime end) =>
        StartNextPeriod.datesAfter(_budget(start: start, end: end));

    test('a calendar month continues with the next calendar month', () {
      final next = after(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(next.start, DateTime(2026, 11, 1));
      expect(next.end, DateTime(2026, 11, 30));

      final nov = after(DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(nov.end, DateTime(2026, 12, 31));

      final dec = after(DateTime(2026, 12, 1), DateTime(2026, 12, 31));
      expect(dec.start, DateTime(2027, 1, 1));
      expect(dec.end, DateTime(2027, 1, 31));

      final feb = after(DateTime(2027, 2, 1), DateTime(2027, 2, 28));
      expect(feb.end, DateTime(2027, 3, 31));
    });

    test('a month from a payday keeps the same day next month', () {
      final next = after(DateTime(2026, 10, 15), DateTime(2026, 11, 14));
      expect(next.start, DateTime(2026, 11, 15));
      expect(next.end, DateTime(2026, 12, 14));
    });

    test('any other period keeps its length', () {
      // 14 days.
      final next = after(DateTime(2026, 10, 1), DateTime(2026, 10, 14));
      expect(next.start, DateTime(2026, 10, 15));
      expect(next.end, DateTime(2026, 10, 28));
    });

    test('a period across a clock change keeps whole days', () {
      // Spans the US (8 Mar) and EU (29 Mar) changes in any time zone.
      final next = after(DateTime(2027, 3, 1), DateTime(2027, 3, 10));
      expect(next.start, DateTime(2027, 3, 11));
      expect(next.end, DateTime(2027, 3, 20));
      final across = after(DateTime(2026, 10, 20), DateTime(2026, 11, 2));
      expect(across.start, DateTime(2026, 11, 3));
      expect(across.end, DateTime(2026, 11, 16));
    });
  });

  group('Start next period', () {
    late ListBudgetRepository budgets;

    setUp(() async {
      await getIt.reset();
      budgets = ListBudgetRepository([
        _budget(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31)),
      ], 'oct');
      getIt
        ..registerSingleton<ManageBudgetUseCase>(
          ManageBudgetUseCase(
            repository: budgets,
            reconcileTabs: FakeReconcileTabUseCase(),
          ),
        )
        ..registerSingleton<CurrencyProvider>(
          CurrencyProvider(
            loadSettingsUseCase: LoadSettingsUseCase(
              repository: FakeSettingsRepository(),
            ),
          ),
        );
    });

    tearDown(() async => getIt.reset());

    Future<void> pumpApp(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => StartNextPeriod.open(context, 'oct'),
                child: const Text('Go'),
              ),
            ),
          ),
          GoRoute(
            // As the app's route reads it.
            path: '/app/budgets/create',
            builder: (_, state) => BudgetFormScreen(
              nextAfterId: state.uri.queryParameters['next'],
            ),
          ),
          GoRoute(
            path: '/app/budgets/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Details ${state.pathParameters['id']}')),
          ),
        ],
      );
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens the form with the next period, the same amount, '
        'currency and set-asides, then opens the new budget', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Next period'), findsOneWidget);
      String value(String label) => tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, label, skipOffstage: false),
          )
          .controller!
          .text;
      expect(value('Budget name'), 'Household');
      expect(value('Budget amount'), '750.5');
      expect(value('Keep aside'), '50');
      expect(value('Savings goal'), '25.25');
      expect(find.text('OMR'), findsOneWidget);
      expect(find.text('1 Nov 2026', skipOffstage: false), findsOneWidget);
      expect(find.text('30 Nov 2026', skipOffstage: false), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.text('Create budget'),
        ),
      );
      await tester.pumpAndSettle();

      final created = budgets.budgets.singleWhere((b) => b.id != 'oct');
      expect(created.startDate, DateTime(2026, 11, 1));
      expect(created.endDate, DateTime(2026, 11, 30));
      expect(created.monthlyAmount, 750.5);
      expect(created.currency, 'OMR');
      expect(created.reservedAmount, 50);
      expect(created.savingsTarget, 25.25);
      expect(created.icon, 'home');
      expect(created.color, '#4CAF50');
      expect(find.text('Details ${created.id}'), findsOneWidget);
    });

    testWidgets('an untouched prefilled form closes without asking', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Go'), findsOneWidget);
      expect(budgets.budgets, hasLength(1));
    });
  });
}
