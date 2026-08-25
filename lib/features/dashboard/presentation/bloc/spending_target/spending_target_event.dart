import 'package:equatable/equatable.dart';

abstract class SpendingTargetEvent extends Equatable {
  const SpendingTargetEvent();

  @override
  List<Object?> get props => [];
}

class SpendingTargetLoad extends SpendingTargetEvent {
  const SpendingTargetLoad();
}

class SpendingTargetRefresh extends SpendingTargetEvent {
  const SpendingTargetRefresh();
}

class SpendingTargetDateChanged extends SpendingTargetEvent {
  final DateTime date;

  const SpendingTargetDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}
