import 'dart:async';
import 'dart:developer' as developer;

import 'package:home_widget/home_widget.dart';

import '../../core/di/injection.dart';
import '../budget/domain/repository/budget_repository.dart';
import '../dashboard/domain/usecases/get_spending_targets_usecase.dart';

/// Keys used to store widget data in SharedPreferences.
/// Native widgets read these keys directly.
class WidgetDataKeys {
  WidgetDataKeys._();

  static const String dailySafeSpending = 'home_widget_daily_safe';
  static const String spentToday = 'home_widget_spent_today';
  static const String status = 'home_widget_status';
  static const String remainingBudget = 'home_widget_remaining';
  static const String remainingDays = 'home_widget_remaining_days';
  static const String currency = 'home_widget_currency';
  static const String lastUpdated = 'home_widget_last_updated';
  static const String hasActiveBudget = 'home_widget_has_budget';
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
/// All calculations come from the existing use cases — no new formulas.
class HomeWidgetService {
  final BudgetRepository _budgetRepository;
  final GetSpendingTargetsUseCase _getSpendingTargetsUseCase;

  HomeWidgetService({
    required BudgetRepository budgetRepository,
    required GetSpendingTargetsUseCase getSpendingTargetsUseCase,
  }) : _budgetRepository = budgetRepository,
       _getSpendingTargetsUseCase = getSpendingTargetsUseCase;

  /// Creates an instance using getIt dependencies.
  factory HomeWidgetService.fromDI() {
    return HomeWidgetService(
      budgetRepository: getIt<BudgetRepository>(),
      getSpendingTargetsUseCase: getIt<GetSpendingTargetsUseCase>(),
    );
  }

  /// Computes current widget data from the existing budget architecture
  /// and persists it via [HomeWidget.saveWidgetData].
  ///
  /// Does NOT duplicate any calculation — reuses [GetSpendingTargetsUseCase].
  Future<void> updateWidgetData({DateTime? referenceDate}) async {
    try {
      final now = referenceDate ?? DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // ── Determine which budgets are active today ──────────────────────
      final activeId = await _budgetRepository.getActiveBudgetId();
      if (activeId == null) {
        await _writeNoBudgetState();
        await _updateNativeWidgets();
        return;
      }

      // ── Use existing GetSpendingTargetsUseCase for per-budget limits ──
      final perBudgetResult = await _getSpendingTargetsUseCase.callPerBudget(
        referenceDate: today,
      );

      if (perBudgetResult is PerBudgetSpendingTargetNoBudget) {
        await _writeNoBudgetState();
        await _updateNativeWidgets();
        return;
      }

      if (perBudgetResult is PerBudgetSpendingTargetError) {
        await _writeErrorState();
        await _updateNativeWidgets();
        return;
      }

      final success = perBudgetResult as PerBudgetSpendingTargetSuccess;
      final budgetLimits = success.budgetLimits;

      if (budgetLimits.isEmpty) {
        await _writeNoBudgetState();
        await _updateNativeWidgets();
        return;
      }

      // ── Compute combined safe spending across active budgets ──────────
      double combinedDailySafe = 0;
      double combinedSpentToday = 0;
      double combinedRemainingBudget = 0;
      int minRemainingDays = 999;
      String currency = 'INR';

      for (final bl in budgetLimits) {
        combinedDailySafe += bl.dailyLimit;
        combinedSpentToday += bl.spentToday;
        combinedRemainingBudget += bl.remainingBudget;
        if (bl.remainingDays < minRemainingDays) {
          minRemainingDays = bl.remainingDays;
        }
        currency = bl.currency;
      }

      // ── Derive status ─────────────────────────────────────────────────
      final bool isOverToday =
          combinedSpentToday > combinedDailySafe && combinedDailySafe > 0;
      final double overspent = isOverToday
          ? combinedSpentToday - combinedDailySafe
          : 0;
      final String status;
      if (isOverToday) {
        status = 'over:${overspent.toStringAsFixed(0)}';
      } else if (combinedDailySafe > 0) {
        status = 'on_track';
      } else {
        status = 'no_budget';
      }

      // ── Write data to SharedPreferences via home_widget ───────────────
      await _saveString(
        WidgetDataKeys.dailySafeSpending,
        combinedDailySafe.toStringAsFixed(2),
      );
      await _saveString(
        WidgetDataKeys.spentToday,
        combinedSpentToday.toStringAsFixed(2),
      );
      await _saveString(WidgetDataKeys.status, status);
      await _saveString(
        WidgetDataKeys.remainingBudget,
        combinedRemainingBudget.toStringAsFixed(2),
      );
      await _saveString(
        WidgetDataKeys.remainingDays,
        minRemainingDays.toString(),
      );
      await _saveString(WidgetDataKeys.currency, currency);
      await _saveString(
        WidgetDataKeys.lastUpdated,
        DateTime.now().toIso8601String(),
      );
      await _saveString(WidgetDataKeys.hasActiveBudget, 'true');

      // ── Notify native widgets to refresh ──────────────────────────────
      await _updateNativeWidgets();
    } catch (e) {
      developer.log(
        '[HomeWidgetService] Error updating widget data: $e',
        name: 'HomeWidgetService',
      );
      await _writeErrorState();
      await _updateNativeWidgets();
    }
  }

  /// Saves the quick-action payload so the widget can trigger navigation.
  Future<void> setQuickActionPayload(String route) async {
    await _saveString(WidgetDataKeys.quickActionPayload, route);
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

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _saveString(String key, String value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  Future<void> _writeNoBudgetState() async {
    await _saveString(WidgetDataKeys.hasActiveBudget, 'false');
    await _saveString(WidgetDataKeys.dailySafeSpending, '0');
    await _saveString(WidgetDataKeys.spentToday, '0');
    await _saveString(WidgetDataKeys.status, 'no_budget');
    await _saveString(WidgetDataKeys.remainingBudget, '0');
    await _saveString(WidgetDataKeys.remainingDays, '0');
    await _saveString(WidgetDataKeys.currency, 'INR');
    await _saveString(
      WidgetDataKeys.lastUpdated,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _writeErrorState() async {
    await _saveString(WidgetDataKeys.hasActiveBudget, 'false');
    await _saveString(WidgetDataKeys.dailySafeSpending, '0');
    await _saveString(WidgetDataKeys.spentToday, '0');
    await _saveString(WidgetDataKeys.status, 'error');
    await _saveString(WidgetDataKeys.remainingBudget, '0');
    await _saveString(WidgetDataKeys.remainingDays, '0');
    await _saveString(WidgetDataKeys.currency, 'INR');
    await _saveString(
      WidgetDataKeys.lastUpdated,
      DateTime.now().toIso8601String(),
    );
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
