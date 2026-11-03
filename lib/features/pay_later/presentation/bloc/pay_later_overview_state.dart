import 'package:equatable/equatable.dart';

import '../../domain/entities/pay_later_overview.dart';

enum PayLaterOverviewStatus { initial, loading, loaded, error }

/// The charts load after the overview, one currency at a time.
enum PayLaterAnalyticsStatus { none, loading, loaded, error }

class PayLaterOverviewState extends Equatable {
  final PayLaterOverviewStatus status;
  final PayLaterOverview? overview;

  /// The currency the charts show; null when no currency is in use.
  final String? currency;
  final PayLaterAnalyticsStatus analyticsStatus;
  final PayLaterAnalytics? analytics;

  /// What a failed first load says.
  final String? errorMessage;

  const PayLaterOverviewState({
    this.status = PayLaterOverviewStatus.initial,
    this.overview,
    this.currency,
    this.analyticsStatus = PayLaterAnalyticsStatus.none,
    this.analytics,
    this.errorMessage,
  });

  PayLaterOverviewState copyWith({
    PayLaterOverviewStatus? status,
    PayLaterOverview? overview,
    String? currency,
    bool clearCurrency = false,
    PayLaterAnalyticsStatus? analyticsStatus,
    PayLaterAnalytics? analytics,
    bool clearAnalytics = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PayLaterOverviewState(
      status: status ?? this.status,
      overview: overview ?? this.overview,
      currency: clearCurrency ? null : (currency ?? this.currency),
      analyticsStatus: analyticsStatus ?? this.analyticsStatus,
      analytics: clearAnalytics ? null : (analytics ?? this.analytics),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    overview,
    currency,
    analyticsStatus,
    analytics,
    errorMessage,
  ];
}
