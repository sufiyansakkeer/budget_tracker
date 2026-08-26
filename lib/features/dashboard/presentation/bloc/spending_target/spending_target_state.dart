import 'package:equatable/equatable.dart';

import '../../../domain/entities/spending_target_entity.dart';

enum SpendingTargetBlocStatus { initial, loading, loaded, empty, error }

class SpendingTargetState extends Equatable {
  final SpendingTargetBlocStatus status;
  final SpendingTargetEntity? targets;
  final String? errorMessage;

  const SpendingTargetState({
    this.status = SpendingTargetBlocStatus.initial,
    this.targets,
    this.errorMessage,
  });

  SpendingTargetState copyWith({
    SpendingTargetBlocStatus? status,
    SpendingTargetEntity? targets,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SpendingTargetState(
      status: status ?? this.status,
      targets: targets ?? this.targets,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, targets, errorMessage];
}
