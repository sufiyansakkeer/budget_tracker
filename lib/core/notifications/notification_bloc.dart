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
/// bloc also listens to expense and budget changes and re-schedules (after a
/// short debounce) to keep "Today's Safe Spending" in the notification
/// current.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationService _notificationService;
  final LoadSettingsUseCase _loadSettingsUseCase;
  final Duration _rescheduleDebounce;
  bool _startupCompleted = false;

  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSubscription;
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
    on<NotificationRequestPermission>(_onRequestPermission);
    on<NotificationSchedule>(_onSchedule);
    on<NotificationCancel>(_onCancel);
    on<NotificationRefreshSchedule>(_onRefreshSchedule);

    _expenseSubscription = RefreshBuses.expenses.changes.listen(
      (_) => _queueReschedule(),
    );
    _budgetSubscription = RefreshBuses.budgets.changes.listen(
      (_) => _queueReschedule(),
    );
  }

  /// Collapses bursts of changes (e.g. a restore) into one re-schedule.
  void _queueReschedule() {
    if (isClosed || state.status != NotificationStatus.ready) return;
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
    return super.close();
  }

  Future<void> _onRefreshSchedule(
    NotificationRefreshSchedule event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.status != NotificationStatus.ready) return;
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

    // Ensure permission is requested if not already granted.
    if (state.status == NotificationStatus.initial) {
      add(const NotificationRequestPermission());
    }
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
          await _notificationService.scheduleTestNotification(settings: data);
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

  Future<void> _onRequestPermission(
    NotificationRequestPermission event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final granted = await _notificationService.requestPermission();
      emit(
        state.copyWith(
          status: granted
              ? NotificationStatus.permissionGranted
              : NotificationStatus.permissionDenied,
          clearError: true,
        ),
      );
    } catch (e, st) {
      debugPrint('[NotificationBloc] Permission request failed: $e\n$st');
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSchedule(
    NotificationSchedule event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationService.scheduleAll(event.settings);
      emit(state.copyWith(status: NotificationStatus.ready, clearError: true));
    } catch (e, st) {
      debugPrint('[NotificationBloc] Scheduling failed: $e\n$st');
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCancel(
    NotificationCancel event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationService.cancelAll();
      emit(state.copyWith(status: NotificationStatus.ready, clearError: true));
    } catch (e, st) {
      debugPrint('[NotificationBloc] Cancel failed: $e\n$st');
      emit(
        state.copyWith(
          status: NotificationStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
