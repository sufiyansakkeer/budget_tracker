import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/update_status.dart';
import '../../domain/usecases/check_for_app_update_usecase.dart';
import 'app_update_event.dart';
import 'app_update_state.dart';

class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  final CheckForAppUpdateUseCase _checkForAppUpdateUseCase;

  /// Tracks whether the auto-launch dialog has already been shown this session.
  bool _launchDialogShown = false;

  AppUpdateBloc({required CheckForAppUpdateUseCase checkForAppUpdateUseCase})
    : _checkForAppUpdateUseCase = checkForAppUpdateUseCase,
      super(const AppUpdateInitial()) {
    on<AppUpdateCheckOnLaunch>(_onCheckOnLaunch);
    on<AppUpdateManualCheck>(_onManualCheck);
    on<AppUpdateDismissed>(_onDismissed);
  }

  Future<void> _onCheckOnLaunch(
    AppUpdateCheckOnLaunch event,
    Emitter<AppUpdateState> emit,
  ) async {
    if (_launchDialogShown) return;

    emit(const AppUpdateChecking());
    final result = await _checkForAppUpdateUseCase();

    switch (result.status) {
      case UpdateStatus.updateAvailable:
        _launchDialogShown = true;
        emit(AppUpdateAvailable(result));
        break;
      case UpdateStatus.upToDate:
      case UpdateStatus.newerVersion:
        emit(AppUpdateUpToDate(result));
        break;
      case UpdateStatus.checkFailed:
        emit(
          AppUpdateCheckFailed(
            result.errorMessage ?? 'Unable to check for updates.',
          ),
        );
        break;
    }
  }

  Future<void> _onManualCheck(
    AppUpdateManualCheck event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(const AppUpdateChecking());
    final result = await _checkForAppUpdateUseCase();

    switch (result.status) {
      case UpdateStatus.updateAvailable:
        emit(AppUpdateAvailable(result));
        break;
      case UpdateStatus.upToDate:
      case UpdateStatus.newerVersion:
        emit(AppUpdateUpToDate(result));
        break;
      case UpdateStatus.checkFailed:
        emit(
          AppUpdateCheckFailed(
            result.errorMessage ?? 'Unable to check for updates.',
          ),
        );
        break;
    }
  }

  void _onDismissed(AppUpdateDismissed event, Emitter<AppUpdateState> emit) {
    // Reset so manual checks from settings can still emit update-available.
    // But do NOT reset _launchDialogShown — it stays true for this session.
  }
}
