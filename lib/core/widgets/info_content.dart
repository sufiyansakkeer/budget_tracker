/// Reusable data model for contextual info/explanation content.
///
/// Each [InfoContent] describes a single explanation panel that can be
/// displayed via [InfoIcon]. The model is intentionally UI-agnostic so
/// explanation definitions can live alongside the business logic that
/// produces them.
class InfoContent {
  /// Title shown at the top of the explanation sheet.
  final String title;

  /// Short description of what this metric/feature is.
  final String whatIsThis;

  /// How the value is calculated. May be null if the metric is
  /// self-explanatory (e.g. "Today's Spending").
  final String? howIsItCalculated;

  /// Concrete example showing the calculation. Formatted for readability.
  final String? example;

  /// Additional notes about edge cases, limitations, or dynamic behaviour.
  final String? additionalNotes;

  /// Privacy notice shown at the bottom when appropriate.
  final String? privacyNote;

  const InfoContent({
    required this.title,
    required this.whatIsThis,
    this.howIsItCalculated,
    this.example,
    this.additionalNotes,
    this.privacyNote,
  });
}
