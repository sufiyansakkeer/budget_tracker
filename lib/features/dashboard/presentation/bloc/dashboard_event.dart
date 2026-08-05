import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class DashboardLoadData extends DashboardEvent {
  const DashboardLoadData();
}

class DashboardRefresh extends DashboardEvent {
  const DashboardRefresh();
}
