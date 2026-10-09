import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/events/refresh_bus.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/usecases/get_spending_targets_usecase.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/widgets/home_widget_payload.dart';
import 'package:monivo/features/widgets/home_widget_service.dart';
import 'package:monivo/features/widgets/widget_refresh_listener.dart';

import '../dashboard/domain/usecases/get_spending_targets_usecase_test.dart'
    show FakeBudgetRepository;
import '../../helpers/safe_to_spend_fakes.dart';

/// The home-screen widget only typesets what the app writes, so every
/// figure and word in the payload must be the one Home shows.
void main() {
  final today = DateTime(2026, 8, 10, 14, 30);
  final calculator = SafeToSpendCalculator(BudgetCalculationService());

  /// Aug 1–31, 22 days left including today.
  SafeToSpendEntity engine({
    double amount = 22000,
    double spentBefore = 0,
    double spentToday = 0,
    String currency = 'INR',
    String name = 'Food',
  }) => calculator.calculate(
    SafeToSpendInput(
      budgetId: 'b1',
      budgetName: name,
      currency: currency,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      today: DateTime(2026, 8, 10),
      budgetAmount: amount,
      periodSpent: spentBefore + spentToday,
      todaySpent: spentToday,
      commitments: const [],
    ),
  );

  Map<String, Object?> ready(
    SafeToSpendEntity e, {
    double utilization = 0.3,
    ColorPalette palette = ColorPalette.defaultPalette,
  }) => HomeWidgetPayload.ready(
    e,
    budgetUtilization: utilization,
    now: today,
    palette: palette,
  );

  Map<String, Object?> section(Map<String, Object?> p, String key) =>
      p[key]! as Map<String, Object?>;

  group('ready payload', () {
    test('the amount is the hero figure, floored and split like Home', () {
      // 1000 ÷ 22 days = 45.4545…
      final e = engine(amount: 1000);
      final safe = section(ready(e), 'safe');

      expect(
        safe['text'],
        SafeToSpendCopy.safeAmount(e.dailySafeToSpend, 'INR'),
      );
      expect(safe['text'], '₹45.45');
      expect(safe['prefix'], '₹');
      expect(safe['whole'], '45');
      expect(safe['fraction'], '.45');
      expect(safe['spoken'], '₹45.45');
    });

    test('a three-decimal currency keeps its symbol and fils', () {
      // 100 ÷ 22 = 4.545454… OMR; the old widget showed "₹4".
      final e = engine(amount: 100, currency: 'OMR');
      final safe = section(ready(e), 'safe');

      expect(
        safe['text'],
        AppMoney.format(e.dailySafeToSpend, currency: 'OMR', floored: true),
      );
      expect(safe['text'], isNot(contains('₹')));
      expect(safe['fraction'], '.545');
      // The symbol carries a left-to-right mark so the digits stay after it.
      expect(safe['prefix'], endsWith('‎'));
    });

    test('Arabic-script symbols stay before the digits, as on Home', () {
      // 100 OMR over 22 days (4.545 a day); 1.25 spent today.
      final e = engine(amount: 100, spentToday: 1.25, currency: 'OMR');
      final today = section(ready(e), 'today');
      final budget = section(ready(e), 'budget');

      // Identical to what AppMoney draws for these figures on Home.
      expect(
        today['spent'],
        AppMoney.format(e.todayDiscretionary, currency: 'OMR'),
      );
      expect(
        today['rest'],
        AppMoney.format(e.remainingToday, currency: 'OMR', floored: true),
      );
      expect(today['spent'], contains('\u200E'));
      // Both figures in the budget line keep their symbol in front.
      expect('\u200E'.allMatches(budget['left']! as String), hasLength(2));
      // Other currencies are untouched.
      final inr = section(ready(engine(spentToday: 400)), 'today');
      expect(inr['spent'], '₹400');
    });

    test('on track: status, today and budget lines match Home', () {
      final e = engine(spentToday: 400);
      final p = ready(e, utilization: 0.25);

      expect(p['v'], HomeWidgetPayload.version);
      expect(p['state'], 'ready');
      expect(p['asOf'], '2026-08-10');
      expect(section(p, 'status'), {'label': 'On track', 'tone': 'positive'});
      expect(section(p, 'today'), {
        'progress': 0.4,
        'spentLabel': 'Spent today',
        'spent': '₹400',
        'restLabel': 'Left today',
        'rest': '₹600',
      });
      expect(section(p, 'budget'), {
        'name': 'Food',
        'daysLeft': '22 days left',
        'left': SafeToSpendCopy.budgetLeftLine(e),
        'progress': 0.25,
        'tone': 'neutral',
      });
      expect(p['summary'], startsWith(SafeToSpendCopy.heroSemantics(e)));
    });

    test('over today\'s amount is caution, with the overspend', () {
      // Daily 1000; 1250.40 spent today.
      final e = engine(spentToday: 1250.40);
      expect(e.status, SafeToSpendStatus.overDailyAllowance);
      final p = ready(e);

      expect(section(p, 'status')['tone'], 'caution');
      expect(section(p, 'today'), containsPair('restLabel', 'Over by'));
      expect(section(p, 'today'), containsPair('rest', '₹250.40'));
      expect(section(p, 'today'), containsPair('restTone', 'caution'));
      expect(section(p, 'today')['progress'], 1.0);
    });

    test('over budget is critical on the status and the budget line', () {
      final e = engine(amount: 3000, spentBefore: 3200.25);
      expect(e.status, SafeToSpendStatus.overBudget);
      final p = ready(e, utilization: 1.07);

      expect(section(p, 'status'), {
        'label': 'Over budget',
        'tone': 'critical',
      });
      expect(section(p, 'budget')['tone'], 'critical');
      expect(section(p, 'budget')['left'], contains('over'));
      // Fractions are clamped for drawing.
      expect(section(p, 'budget')['progress'], 1.0);
    });

    test('survives a JSON round trip', () {
      final p = ready(engine(spentToday: 120));
      expect(jsonDecode(HomeWidgetPayload.encode(p)), p);
    });
  });

  group('colours', () {
    Map<String, Object?> colors(ColorPalette palette, String mode) =>
        section(section(ready(engine(), palette: palette), 'colors'), mode);

    test('every colour is #AARRGGBB, in both modes', () {
      for (final mode in ['light', 'dark']) {
        final c = colors(ColorPalette.defaultPalette, mode);
        expect(c.keys, {
          'surface',
          'ink',
          'muted',
          'track',
          'accent',
          'onAccent',
          'divider',
          'positive',
          'caution',
          'critical',
          'neutral',
        });
        for (final value in c.values) {
          expect(value, matches(RegExp(r'^#[0-9A-F]{8}$')));
        }
      }
    });

    test('the accent follows the palette; status colours do not', () {
      final a = colors(ColorPalette.defaultPalette, 'light');
      final b = colors(ColorPalette.ocean, 'light');
      expect(a['accent'], isNot(b['accent']));
      for (final tone in ['positive', 'caution', 'critical']) {
        expect(a[tone], b[tone], reason: tone);
      }
    });
  });

  group('other states', () {
    test('no budget and error carry a message, no figures', () {
      final none = HomeWidgetPayload.noBudget(
        now: today,
        palette: ColorPalette.defaultPalette,
      );
      final error = HomeWidgetPayload.error(
        now: today,
        palette: ColorPalette.defaultPalette,
      );
      expect(none['state'], 'noBudget');
      expect(section(none, 'message'), {
        'title': 'No budget running',
        'body': 'Open Monivo to start or choose a budget.',
        'short': 'No budget',
      });
      expect(error['state'], 'error');
      expect(section(error, 'message'), {
        'title': "Couldn't load your budget",
        'body': 'Open Monivo and try again.',
        'short': "Couldn't load",
      });
      for (final p in [none, error]) {
        expect(p.containsKey('safe'), isFalse);
        expect(p['asOf'], '2026-08-10');
        expect(section(p, 'stale')['title'], 'Tap to update');
      }
    });
  });

  group('HomeWidgetService.buildPayload', () {
    BudgetEntity budget({DateTime? start, DateTime? end}) => BudgetEntity(
      id: 'b1',
      name: 'Groceries',
      monthlyAmount: 22000,
      remainingAmount: 22000,
      currency: 'INR',
      startDate: start ?? DateTime(2026, 8, 1),
      endDate: end ?? DateTime(2026, 8, 31),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    HomeWidgetService service(FakeBudgetRepository repository) =>
        HomeWidgetService(
          budgetRepository: repository,
          getSpendingTargetsUseCase: GetSpendingTargetsUseCase(
            repository: repository,
            calculationService: BudgetCalculationService(),
            safeToSpend: fakeSafeToSpendUseCase(repository, clock: () => today),
          ),
          palette: () async => ColorPalette.forest,
        );

    test('no active budget', () async {
      final p = await service(FakeBudgetRepository()).buildPayload(today);
      expect(p['state'], 'noBudget');
    });

    test('the active budget running today', () async {
      final repository = FakeBudgetRepository()
        ..budget = budget()
        ..budgets = [budget()];
      final p = await service(repository).buildPayload(today);

      expect(p['state'], 'ready');
      expect(section(p, 'budget')['name'], 'Groceries');
      expect(section(p, 'safe')['text'], '₹1,000');
      // Drawn in the user's palette.
      expect(
        p['colors'],
        HomeWidgetPayload.noBudget(
          now: today,
          palette: ColorPalette.forest,
        )['colors'],
      );
    });

    test('waits for the saved palette before drawing', () async {
      // On a slow start the theme is still loading when the widget is
      // first written; it must not fall back to the default palette.
      final loaded = Completer<ColorPalette>();
      final repository = FakeBudgetRepository()
        ..budget = budget()
        ..budgets = [budget()];
      final widget = HomeWidgetService(
        budgetRepository: repository,
        getSpendingTargetsUseCase: GetSpendingTargetsUseCase(
          repository: repository,
          calculationService: BudgetCalculationService(),
          safeToSpend: fakeSafeToSpendUseCase(repository, clock: () => today),
        ),
        palette: () => loaded.future,
      );
      final payload = widget.buildPayload(today);
      loaded.complete(ColorPalette.blossomVapor);

      expect(
        (await payload)['colors'],
        HomeWidgetPayload.noBudget(
          now: today,
          palette: ColorPalette.blossomVapor,
        )['colors'],
      );
    });

    test('an active budget that has not started is "no budget"', () async {
      final later = budget(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      final repository = FakeBudgetRepository()
        ..budget = later
        ..budgets = [later];
      final p = await service(repository).buildPayload(today);
      expect(p['state'], 'noBudget');
    });
  });

  group('WidgetRefreshListener', () {
    test('refreshes on expense, budget and bill changes', () async {
      final service = _CountingWidgetService();
      final listener = WidgetRefreshListener(widgetService: service)
        ..startListening();
      addTearDown(listener.stopListening);

      RefreshBuses.bills.notifyChanged();
      RefreshBuses.expenses.notifyChanged();
      RefreshBuses.budgets.notifyChanged();
      await Future<void>.delayed(Duration.zero);

      expect(service.updates, 3);

      listener.stopListening();
      RefreshBuses.bills.notifyChanged();
      await Future<void>.delayed(Duration.zero);
      expect(service.updates, 3);
    });

    test('refreshes when the palette changes', () async {
      final service = _CountingWidgetService();
      final palettes = StreamController<Object?>();
      addTearDown(palettes.close);
      final listener = WidgetRefreshListener(
        widgetService: service,
        appearanceChanges: palettes.stream,
      )..startListening();
      addTearDown(listener.stopListening);

      palettes.add(ColorPalette.ocean);
      await Future<void>.delayed(Duration.zero);
      expect(service.updates, 1);
    });
  });
}

/// Counts update requests instead of writing to the platform widget store.
class _CountingWidgetService extends HomeWidgetService {
  _CountingWidgetService() : this._(FakeBudgetRepository());

  _CountingWidgetService._(FakeBudgetRepository repository)
    : super(
        budgetRepository: repository,
        getSpendingTargetsUseCase: GetSpendingTargetsUseCase(
          repository: repository,
          calculationService: BudgetCalculationService(),
          safeToSpend: fakeSafeToSpendUseCase(repository),
        ),
      );

  int updates = 0;

  @override
  Future<void> updateWidgetData({DateTime? referenceDate}) async => updates++;
}
