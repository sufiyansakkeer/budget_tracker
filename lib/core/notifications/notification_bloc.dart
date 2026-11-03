import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/settings/domain/entities/settings_failure.dart';
import '../../features/settings/domain/services/notification_service.dart';
import '../../features/settings/domain/usecases/load_settings_usecase.dart';
import '../events/refresh_bus.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// Owns notification initialization, permission, and scheduling at startup.
///
/// Failures never block app launch — the dashboard remains usable even when
/// permission is denied or scheduling fails.
///
/// The morning notification's text is computed when it is scheduled, so the
/// bloc also listens to expense, budget and bill changes (bills set aside
/// from a budget change its safe amount) and re-schedules (after a short
/// debounce) to keep "Today's Safe Spending" in the notification current.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationService _notificationService;
  final LoadSettingsUseCase _loadSettingsUseCase;
  final Duration _rescheduleDebounce;
  bool _startupCompleted = false;

  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSubscription;
  StreamSubscription<void>? _billSubscription;
  Timer? _rescheduleTimer;

  NotificationBloc({
    required NotificationService notificationService,
    required LoadSettingsUseCase loadSettingsUseCase,
    Duration rescheduleDebounce = const Duration(seconds: 3),
  }) : _notificationService = notificationService,
       _loadSettingsUseCase = loadSettingsUseCase,
       _rescheduleDebounce = rescheduleDebounce,
       super(const NotificationState()) {
    on<NotificationInitialize>(_onInitialize);
    on<NotificationRefreshSchedule>(_onRefreshSchedule);

    _expenseSubscription = RefreshBuses.expenses.changes.listen(
      (_) => _queueReschedule(),
    );
    _budgetSubscription = RefreshBuses.budgets.changes.listen(
      (_) => _queueReschedule(),
    );
    _billSubscription = RefreshBuses.bills.changes.listen(
      (_) => _queueReschedule(),
    );
  }

  /// Whether re-scheduling makes sense: notifications are ready, or startup
  /// has finished another way (a permission refused at startup can be
  /// granted later in system settings, and the amounts must still update).
  bool get _canReschedule =>
      _startupCompleted || state.status == NotificationStatus.ready;

  /// Collapses bursts of changes (e.g. a restore) into one re-schedule.
  void _queueReschedule() {
    if (isClosed || !_canReschedule) return;
    _rescheduleTimer?.cancel();
    _rescheduleTimer = Timer(_rescheduleDebounce, () {
      if (!isClosed) add(const NotificationRefreshSchedule());
    });
  }

  @override
  Future<void> close() {
    _rescheduleTimer?.cancel();
    _expenseSubscription?.cancel();
    _budgetSubscription?.cancel();
    _billSubscription?.cancel();
    return super.close();
  }

  Future<void> _onRefreshSchedule(
    NotificationRefreshSchedule event,
    Emitter<NotificationState> emit,
  ) async {
    if (!_canReschedule) return;
    final result = await _loadSettingsUseCase();
    if (result case SettingsSuccess(:final data)) {
      if (!data.notifications.notificationsEnabled) return;
      try {
        await _notificationService.scheduleAll(data);
        debugPrint('[NotificationBloc] Re-scheduled after data change');
      } catch (e) {
        // Keep the previous schedule; the next change will retry.
        debugPrint('[NotificationBloc] Re-schedule failed: $e');
      }
    }
  }

  /// Runs the full startup flow once and completes when ready or denied.
  Future<void> initializeOnStartup() async {
    if (_startupCompleted) return;
    add(const NotificationInitialize());

    // Wait for initialization or error before proceeding.
    await stream.firstWhere(
      (state) =>
          state.status == NotificationStatus.ready ||
          state.status == NotificationStatus.permissionDenied ||
          state.status == NotificationStatus.error,
    );
  }

  Future<void> _onInitialize(
    NotificationInitialize event,
    Emitter<NotificationState> emit,
  ) async {
    if (_startupCompleted) {
      if (state.status == NotificationStatus.initial) {
        emit(
          state.copyWith(status: NotificationStatus.ready, clearError: true),
        );
      }
      return;
    }

    emit(
      state.copyWith(status: NotificationStatus.initializing, clearError: true),
    );

    try {
      // Initialize the notification service.
      final initialized = await _notificationService.initialize();
      if (!initialized) {
        emit(
          state.copyWith(
            status: NotificationStatus.error,
            errorMessage: 'Failed to initialize notification service',
          ),
        );
        _startupCompleted = true;
        return;
      }

      // Request permission if not already granted.
      final hasPermission = await _notificationService.requestPermission();
      if (!hasPermission) {
        debugPrint('[NotificationBloc] Notification permission denied');
        emit(state.copyWith(status: NotificationStatus.permissionDenied));
        _startupCompleted = true;
        return;
      }

      emit(state.copyWith(status: NotificationStatus.permissionGranted));

      // Load settings and schedule notifications.
      final result = await _loadSettingsUseCase();
      if (result case SettingsSuccess(:final data)) {
        await _notificationService.scheduleAll(data);

        if (kDebugMode) {
          await _notificationService.scheduleTestNotification();
          debugPrint(
            '[NotificationBloc] Debug test notification scheduled for +1 minute',
          );
        }

        emit(
          state.copyWith(status: NotificationStatus.ready, clearError: true),
        );
        debugPrint('[NotificationBloc] Notifications scheduled successfully');
      } else {
        emit(
          state.copyWith(
            status: NotificationStatus.ready,
            errorMessage:
                'Notifications ready but settings could not be loaded',
          ),
        );
      }
    } catch (e, st) {
      debugPrint(
        '[NotificationBloc] Error initializing notifications: $e\n$st',
      );
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      _startupCompleted = true;
    }
  }
}
