import 'package:equatable/equatable.dart';

import '../../domain/entities/budget_analytics_entity.dart';
import '../../domain/entities/budget_summary_entity.dart';

enum BudgetBlocStatus { initial, loading, loaded, error }

class BudgetState extends Equatable {
  final BudgetBlocStatus status;
  final BudgetSummaryEntity? summary;
  final BudgetAnalyticsEntity? analytics;
  final String? errorMessage;

  const BudgetState({
    this.status = BudgetBlocStatus.initial,
    this.summary,
    this.analytics,
    this.errorMessage,
  });

  BudgetState copyWith({
    BudgetBlocStatus? status,
    BudgetSummaryEntity? summary,
    BudgetAnalyticsEntity? analytics,
    String? errorMessage,
    bool clearError = false,
    bool clearSummary = false,
    bool clearAnalytics = false,
  }) {
    return BudgetState(
      status: status ?? this.status,
      summary: clearSummary ? null : (summary ?? this.summary),
      analytics: clearAnalytics ? null : (analytics ?? this.analytics),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, summary, analytics, errorMessage];
}
