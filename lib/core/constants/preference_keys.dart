/// Keys for values stored in `SharedPreferences`.
///
/// Every key lives here so that two features can never disagree on the
/// spelling of a shared preference (the active-budget id used to be declared
/// in three separate files).
abstract final class PreferenceKeys {
  /// Id of the budget the dashboard, reports, notifications and the
  /// home-screen widget are scoped to.
  static const String activeBudgetId = 'active_budget_id';

  /// `true` until onboarding has completed once.
  static const String isFirstLaunch = 'isFirstLaunch';

  /// Currency converter: last source currency code (e.g. `OMR`).
  static const String converterSourceCurrency = 'converter_source_currency';

  /// Currency converter: last target currency code (e.g. `INR`).
  static const String converterTargetCurrency = 'converter_target_currency';

  /// Currency converter: last valid amount the user entered, as typed.
  static const String converterAmount = 'converter_amount';
}
