import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/usecases/get_budget_summary_usecase.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/repository/bill_repository.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/spending_target_entity.dart';
import '../../domain/entities/spending_target_status.dart';
import '../../domain/usecases/get_recent_expenses_usecase.dart';
import '../../domain/usecases/get_safe_to_spend_usecase.dart';
import '../../domain/usecases/get_smart_insights_usecase.dart';
import '../../domain/usecases/get_spending_targets_usecase.dart';
import '../../domain/usecases/get_spending_pace_usecase.dart';
import '../../domain/entities/spending_pace.dart';
import '../../../../core/events/refresh_bus.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetBudgetSummaryUseCase getBudgetSummaryUseCase;
  final GetRecentExpensesUseCase getRecentExpensesUseCase;
  final GetSmartInsightsUseCase getSmartInsightsUseCase;
  final GetSpendingTargetsUseCase getSpendingTargetsUseCase;
  final GetSafeToSpendUseCase getSafeToSpendUseCase;
  final BudgetRepository budgetRepository;
  final BillRepository billRepository;

  /// Optional: without it the dashboard simply shows no pace chart.
  final GetSpendingPaceUseCase? getSpendingPaceUseCase;

  /// Source of "today" (time of day stripped once per load). Tests inject a
  /// fixed clock.
  final DateTime Function() _clock;

  DashboardBloc({
    required this.getBudgetSummaryUseCase,
    required this.getRecentExpensesUseCase,
    required this.getSmartInsightsUseCase,
    required this.getSpendingTargetsUseCase,
    required this.getSafeToSpendUseCase,
    required this.budgetRepository,
    required this.billRepository,
    this.getSpendingPaceUseCase,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const DashboardInitial()) {
    on<DashboardLoadData>(_onLoadData);
    on<DashboardRefresh>(_onRefresh);

    // Auto-refresh when expenses change (created, updated, or deleted).
    _refreshSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });

    _budgetSwitchSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });

    _billRefreshSubscription = RefreshBuses.bills.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });
  }

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;
  StreamSubscription<void>? _billRefreshSubscription;

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    _billRefreshSubscription?.cancel();
    return super.close();
  }

  /// Whether a dashboard (running or not) is on screen, so a refresh keeps
  /// it instead of flashing the skeleton or the error view.
  bool get _hasContent =>
      state is DashboardLoaded || state is DashboardNotRunning;

  /// Incremented by every load. Three buses can each trigger a refresh
  /// while another is in flight; only the latest load may publish, or an
  /// older result landing last would make the numbers animate backwards.
  int _loadToken = 0;

  Future<void> _onLoadData(
    DashboardLoadData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    await _load(emit);
  }

  Future<void> _onRefresh(
    DashboardRefresh event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      // Keep the current content on screen while refreshing so the dashboard
      // never flashes back to a skeleton after adding an expense. Only the
      // first load shows the skeleton.
      if (!_hasContent) {
        emit(const DashboardLoading());
      }
      await _load(emit);
    } finally {
      event.completion?.complete();
    }
  }

  /// Loads everything the dashboard shows. A failure anywhere in the
  /// storage stack becomes a [DashboardError] with the real message rather
  /// than an unhandled exception that would leave the screen on its loading
  /// skeleton forever with nothing in the log. A failed *refresh* keeps the
  /// data already on screen instead of swapping the whole page for the
  /// error view.
  Future<void> _load(Emitter<DashboardState> emit) async {
    final token = ++_loadToken;
    try {
      await _loadOrThrow(emit, isCurrent: () => token == _loadToken);
    } catch (error, stackTrace) {
      developer.log(
        '[Dashboard] Failed to load dashboard data',
        name: 'Dashboard',
        error: error,
        stackTrace: stackTrace,
      );
      if (token != _loadToken || _hasContent) return;
      emit(DashboardError(message: 'Could not load your dashboard: $error'));
    }
  }

  Future<void> _loadOrThrow(
    Emitter<DashboardState> emit, {
    required bool Function() isCurrent,
  }) async {
    // One "today" for every figure in this load: the summary, every
    // budget's safe-to-spend, recent expenses and upcoming bills.
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    final activeId = await budgetRepository.getActiveBudgetId();
    if (!isCurrent()) return;
    if (activeId == null) {
      emit(const DashboardEmpty());
      return;
    }

    final budgetResult = await getBudgetSummaryUseCase(
      budgetId: activeId,
      referenceDate: today,
    );
    if (!isCurrent()) return;

    switch (budgetResult) {
      case BudgetError(:final failure):
        if (failure.type == BudgetErrorType.invalidDate) {
          // Today is outside the active budget's period.
          await _loadNotRunning(
            emit,
            activeId: activeId,
            today: today,
            isCurrent: isCurrent,
          );
          return;
        }
        emit(_resolveErrorState(failure));
        return;

      case BudgetSuccess(:final data):
        final recentExpenses = await getRecentExpensesUseCase(
          budgetId: activeId,
          referenceDate: today,
        );
        final upcomingBills = await _upcomingBills(today);
        final perBudget = await _perBudgetLimits(today);

        // Load per-budget daily spending limits (primary data source).
        List<BudgetDailyLimitEntity> budgetDailyLimits = [];
        SpendingTargetEntity? spendingTarget;
        SafeToSpendEntity? activeSafeToSpend;
        if (perBudget != null) {
          budgetDailyLimits = perBudget.budgetLimits;
          // Legacy target for the ACTIVE budget only (never combined).
          spendingTarget = _deriveSpendingTarget(perBudget, activeId);
          for (final limit in budgetDailyLimits) {
            if (limit.budgetId == activeId) {
              activeSafeToSpend = limit.safeToSpend;
              break;
            }
          }
        }

        // Archived budgets get no daily figure. Tell that apart from figures
        // that failed to compute, which a retry can fix.
        final activeArchived =
            activeSafeToSpend == null && await _isArchived(activeId);

        final spendingPace = await _spendingPace(activeSafeToSpend);

        final insights = getSmartInsightsUseCase(
          data,
          spendingTarget: spendingTarget,
          budgetDailyLimits: budgetDailyLimits,
          safeToSpend: activeSafeToSpend,
        );

        // A newer load started while this one was awaiting; let it publish.
        if (!isCurrent()) return;

        emit(
          DashboardLoaded(
            budgetSummary: data,
            recentExpenses: recentExpenses,
            insights: insights,
            upcomingBills: upcomingBills,
            spendingTarget: spendingTarget,
            budgetDailyLimits: budgetDailyLimits,
            activeBudgetId: activeId,
            activeBudgetArchived: activeArchived,
            spendingPace: spendingPace,
          ),
        );
    }
  }

  /// The active budget's pace, or null when there is none to show or it
  /// cannot be read (not critical for the dashboard).
  Future<SpendingPace?> _spendingPace(SafeToSpendEntity? safeToSpend) async {
    final useCase = getSpendingPaceUseCase;
    if (useCase == null || safeToSpend == null) return null;
    try {
      return await useCase(safeToSpend);
    } catch (_) {
      return null;
    }
  }

  /// Whether budget [id] is archived; false when it cannot be read.
  Future<bool> _isArchived(String id) async {
    try {
      return (await budgetRepository.getBudgetById(id))?.isArchived ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The active budget has not started or has ended: show the engine's
  /// result for it (no daily figure) next to the budgets running today.
  Future<void> _loadNotRunning(
    Emitter<DashboardState> emit, {
    required String activeId,
    required DateTime today,
    required bool Function() isCurrent,
  }) async {
    final result = await getSafeToSpendUseCase(
      budgetId: activeId,
      referenceDate: today,
    );
    if (!isCurrent()) return;

    switch (result) {
      case BudgetError(:final failure):
        emit(_resolveErrorState(failure));
      case BudgetSuccess(:final data):
        final recentExpenses = await getRecentExpensesUseCase(
          budgetId: activeId,
          referenceDate: today,
        );
        final upcomingBills = await _upcomingBills(today);
        final perBudget = await _perBudgetLimits(today);
        if (!isCurrent()) return;

        emit(
          DashboardNotRunning(
            activeBudgetId: activeId,
            safeToSpend: data,
            recentExpenses: recentExpenses,
            upcomingBills: upcomingBills,
            otherBudgetLimits: [
              for (final limit in perBudget?.budgetLimits ?? const [])
                if (limit.budgetId != activeId) limit,
            ],
          ),
        );
    }
  }

  /// The next few unpaid bills, soonest first; empty when bills cannot be
  /// read (not critical for the dashboard).
  Future<List<BillEntity>> _upcomingBills(DateTime today) async {
    try {
      // Soonest first, straight from the due-date index.
      return await billRepository.getUpcomingBills(from: today);
    } catch (_) {
      return const [];
    }
  }

  /// Every running budget's daily limit (each carrying its safe-to-spend
  /// entity), or null when unavailable (not critical for the dashboard).
  Future<PerBudgetSpendingTargetSuccess?> _perBudgetLimits(
    DateTime today,
  ) async {
    try {
      final result = await getSpendingTargetsUseCase.callPerBudget(
        referenceDate: today,
      );
      return result is PerBudgetSpendingTargetSuccess ? result : null;
    } catch (_) {
      return null;
    }
  }

  DashboardState _resolveErrorState(BudgetFailure failure) {
    if (failure.type == BudgetErrorType.notFound) {
      return const DashboardEmpty();
    }
    return DashboardError(message: failure.message);
  }

  /// Derives a legacy [SpendingTargetEntity] for the active budget from the
  /// per-budget data. Daily and weekly amounts are never combined across
  /// budgets; if the active budget is not running today, no target is derived.
  SpendingTargetEntity? _deriveSpendingTarget(
    PerBudgetSpendingTargetSuccess result,
    String activeBudgetId,
  ) {
    BudgetDailyLimitEntity? active;
    for (final bl in result.budgetLimits) {
      if (bl.budgetId == activeBudgetId) {
        active = bl;
        break;
      }
    }
    if (active == null) return null;

    final dailySpent = active.spentToday;
    final weeklyTarget = active.weeklyTarget;
    final weeklySpent = active.weeklySpent;
    final dailyTarget = active.dailyLimit;
    final dailyRemaining = (dailyTarget - dailySpent).clamp(
      0.0,
      double.infinity,
    );
    final dailyExceeded = dailySpent > dailyTarget
        ? dailySpent - dailyTarget
        : 0.0;
    final dailyProgress = dailyTarget > 0
        ? (dailySpent / dailyTarget).clamp(0.0, 1.0)
        : 0.0;
    final dailyStatus = _targetStatus(dailySpent, dailyTarget);

    final weeklyRemaining = (weeklyTarget - weeklySpent).clamp(
      0.0,
      double.infinity,
    );
    final weeklyExceeded = weeklySpent > weeklyTarget
        ? weeklySpent - weeklyTarget
        : 0.0;
    final weeklyProgress = weeklyTarget > 0
        ? (weeklySpent / weeklyTarget).clamp(0.0, 1.0)
        : 0.0;
    final weeklyStatus = _targetStatus(weeklySpent, weeklyTarget);

    return SpendingTargetEntity(
      dailyTarget: dailyTarget,
      dailySpent: dailySpent,
      dailyRemaining: dailyRemaining,
      dailyExceeded: dailyExceeded,
      dailyProgress: dailyProgress,
      dailyStatus: dailyStatus,
      weeklyTarget: weeklyTarget,
      weeklySpent: weeklySpent,
      weeklyRemaining: weeklyRemaining,
      weeklyExceeded: weeklyExceeded,
      weeklyProgress: weeklyProgress,
      weeklyStatus: weeklyStatus,
      currency: result.currency,
    );
  }

  SpendingTargetStatus _targetStatus(double spent, double target) {
    if (target <= 0) return SpendingTargetStatus.onTrack;
    final ratio = spent / target;
    if (ratio > 1.0) return SpendingTargetStatus.exceeded;
    if (ratio >= 0.8) return SpendingTargetStatus.nearLimit;
    return SpendingTargetStatus.onTrack;
  }
}
