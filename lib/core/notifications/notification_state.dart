import 'package:equatable/equatable.dart';

enum NotificationStatus {
  initial,
  initializing,
  permissionGranted,
  permissionDenied,
  ready,
  error,
}

/// State for notification initialization and permission flow.
class NotificationState extends Equatable {
  final NotificationStatus status;
  final String? errorMessage;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.errorMessage,
  });

  NotificationState copyWith({
    NotificationStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
