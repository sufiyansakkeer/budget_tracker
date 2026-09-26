import 'dart:async';

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
  /// Completed when the refresh has finished, whether or not the data
  /// changed. Pull-to-refresh awaits it; an unchanged reload never emits a
  /// new state, so waiting on the stream would spin until a timeout.
  final Completer<void>? completion;

  const DashboardRefresh({this.completion});
}
