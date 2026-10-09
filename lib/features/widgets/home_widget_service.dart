import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/di/injection.dart';
import '../budget/domain/repository/budget_repository.dart';
import '../dashboard/domain/entities/budget_daily_limit_entity.dart';
import '../dashboard/domain/usecases/get_spending_targets_usecase.dart';
import '../settings/domain/entities/color_palette_entity.dart';
import '../settings/presentation/bloc/theme/theme_bloc.dart';
import 'home_widget_payload.dart';

/// Keys used to store widget data in the shared widget store
/// (SharedPreferences on Android, the App Group's UserDefaults on iOS).
/// Native widgets read these keys directly.
class WidgetDataKeys {
  WidgetDataKeys._();

  /// The whole widget state as one JSON string ([HomeWidgetPayload]).
  static const String payload = 'home_widget_payload';
  static const String quickActionPayload = 'home_widget_quick_action';
}

/// Stores the route the user navigated to from a home-screen widget tap.
/// The GoRouter checks this value to handle deep-link routing on cold start.
String? _pendingWidgetRoute;

/// Returns the pending widget route and clears it (consumed once).
String? consumePendingWidgetRoute() {
  final route = _pendingWidgetRoute;
  _pendingWidgetRoute = null;
  return route;
}

/// Sets the pending widget route (called during app startup from widget).
void setPendingWidgetRoute(String? route) {
  _pendingWidgetRoute = route;
}

/// Resolves a widget URI to the exact application route:
/// - Add Expense button: '/app/expenses/add'
/// - Widget body tap: '/app/home' (Dashboard)
String? resolveWidgetUriToRoute(Uri? uri) {
  if (uri == null) return null;
  final str = uri.toString().toLowerCase();
  final path = uri.path.toLowerCase();
  if (str.contains('expense') ||
      str.contains('add') ||
      path.contains('expense') ||
      path.contains('add')) {
    return '/app/expenses/add';
  }
  return '/app/home';
}

/// Service that bridges the existing budget/expense architecture with
/// home-screen widgets.
///
/// The widget shows the ACTIVE budget only: its Today's Safe Spending, what
/// was spent and is left today, and the budget behind it. Amounts are never
/// combined across budgets. All figures come from the existing use cases and
/// are worded by [HomeWidgetPayload] with the app's own formatters — no new
/// formulas, and no money formatting in native code.
class HomeWidgetService {
  final BudgetRepository _budgetRepository;
  final GetSpendingTargetsUseCase _getSpendingTargetsUseCase;
  final Future<ColorPalette> Function() _palette;

  /// Updates run one after another, so a slow older update can never
  /// overwrite a newer one.
  Future<void> _queue = Future<void>.value();

  HomeWidgetService({
    required BudgetRepository budgetRepository,
    required GetSpendingTargetsUseCase getSpendingTargetsUseCase,
    Future<ColorPalette> Function()? palette,
  }) : _budgetRepository = budgetRepository,
       _getSpendingTargetsUseCase = getSpendingTargetsUseCase,
       _palette = palette ?? (() async => ColorPalette.defaultPalette);

  /// Creates an instance using getIt dependencies. The widget follows the
  /// palette the user picked in the app.
  factory HomeWidgetService.fromDI() {
    return HomeWidgetService(
      budgetRepository: getIt<BudgetRepository>(),
      getSpendingTargetsUseCase: getIt<GetSpendingTargetsUseCase>(),
      palette: () async {
        // main() stops waiting for the saved theme after a second; the
        // widget must still get the user's palette, not the default.
        final themes = getIt<ThemeBloc>();
        await themes.ready;
        return themes.state.palette;
      },
    );
  }

  /// Works out the widget's state from the existing budget architecture,
  /// stores it and asks the native widgets to redraw.
  ///
  /// Does NOT duplicate any calculation — reuses [GetSpendingTargetsUseCase].
  Future<void> updateWidgetData({DateTime? referenceDate}) {
    final next = _queue.then((_) => _update(referenceDate));
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _update(DateTime? referenceDate) async {
    final now = referenceDate ?? DateTime.now();
    Map<String, Object?> payload;
    try {
      payload = await buildPayload(now);
    } catch (e) {
      developer.log(
        '[HomeWidgetService] Error updating widget data: $e',
        name: 'HomeWidgetService',
      );
      payload = HomeWidgetPayload.error(
        now: now,
        palette: await _safePalette(),
      );
    }
    try {
      await HomeWidget.saveWidgetData<String>(
        WidgetDataKeys.payload,
        HomeWidgetPayload.encode(payload),
      );
    } catch (e) {
      developer.log(
        '[HomeWidgetService] Error saving widget data: $e',
        name: 'HomeWidgetService',
      );
    }
    await _updateNativeWidgets();
  }

  /// The payload for [now]: the active budget's figures when it runs today,
  /// otherwise the no-budget or error state.
  @visibleForTesting
  Future<Map<String, Object?>> buildPayload(DateTime now) async {
    final palette = await _safePalette();
    final today = DateTime(now.year, now.month, now.day);

    final activeId = await _budgetRepository.getActiveBudgetId();
    if (activeId == null) {
      return HomeWidgetPayload.noBudget(now: now, palette: palette);
    }

    final result = await _getSpendingTargetsUseCase.callPerBudget(
      referenceDate: today,
    );
    switch (result) {
      case PerBudgetSpendingTargetNoBudget():
        return HomeWidgetPayload.noBudget(now: now, palette: palette);
      case PerBudgetSpendingTargetError():
        return HomeWidgetPayload.error(now: now, palette: palette);
      case PerBudgetSpendingTargetSuccess(:final budgetLimits):
        // The ACTIVE budget's limit only (never combined).
        BudgetDailyLimitEntity? active;
        for (final limit in budgetLimits) {
          if (limit.budgetId == activeId) {
            active = limit;
            break;
          }
        }
        // Not running today: its period does not include today.
        if (active == null) {
          return HomeWidgetPayload.noBudget(now: now, palette: palette);
        }
        final engine = active.safeToSpend;
        // Every running budget's limit carries the engine's result; without
        // it there is no figure to show (Home shows its unavailable state).
        if (engine == null) {
          return HomeWidgetPayload.error(now: now, palette: palette);
        }
        return HomeWidgetPayload.ready(
          engine,
          budgetUtilization: active.budgetUtilization,
          now: now,
          palette: palette,
        );
    }
  }

  Future<ColorPalette> _safePalette() async {
    try {
      return await _palette();
    } catch (_) {
      return ColorPalette.defaultPalette;
    }
  }

  /// Saves the quick-action payload so the widget can trigger navigation.
  Future<void> setQuickActionPayload(String route) async {
    await HomeWidget.saveWidgetData<String>(
      WidgetDataKeys.quickActionPayload,
      route,
    );
  }

  /// Clears the quick-action payload after it has been consumed.
  Future<void> clearQuickActionPayload() async {
    await HomeWidget.saveWidgetData<String>(
      WidgetDataKeys.quickActionPayload,
      null,
    );
  }

  /// Reads the quick-action payload that was set before app launch.
  Future<String?> getQuickActionPayload() async {
    return HomeWidget.getWidgetData<String>(WidgetDataKeys.quickActionPayload);
  }

  Future<void> _updateNativeWidgets() async {
    try {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.monivo.HomeScreenWidgetProvider',
        iOSName: 'MonivoWidget',
      );
    } catch (e) {
      developer.log(
        '[HomeWidgetService] Error updating native widgets: $e',
        name: 'HomeWidgetService',
      );
    }
  }
}
