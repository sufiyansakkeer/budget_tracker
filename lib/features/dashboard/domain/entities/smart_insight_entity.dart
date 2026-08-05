import 'package:equatable/equatable.dart';

/// Severity/type of a smart insight message.
enum InsightType {
  /// Positive, encouraging insight (e.g. on track to save).
  positive,

  /// Cautionary insight (e.g. approaching budget limit).
  warning,

  /// Negative insight (e.g. exceeded budget).
  negative,

  /// Neutral informational insight.
  info,
}

/// A user-facing insight message derived exclusively from the Budget Engine.
///
/// The Dashboard only displays these; it never generates them.
class SmartInsight extends Equatable {
  /// Stable identifier for the insight rule that produced this message.
  final String id;

  /// Human-readable message shown to the user.
  final String message;

  /// Visual severity used to style the insight card.
  final InsightType type;

  const SmartInsight({
    required this.id,
    required this.message,
    required this.type,
  });

  @override
  List<Object?> get props => [id, message, type];
}
