import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/entities/smart_insight_entity.dart';

/// Decides which smart insights earn a place on Home.
///
/// The insights use case writes one sentence per rule. Several of those
/// sentences restate what the redesigned Home already shows, and showing a
/// fact twice is noise, so this filters by the rule id (never by rewriting a
/// message) and orders what is left by severity:
///
/// | Insight id                         | Already shown by                 |
/// | ---------------------------------- | -------------------------------- |
/// | `safe_spend_forecast_short` / `_ok` | the hero's explanation and the pace chart |
/// | `budget_progress`, `per_budget_progress_*` | the hero's budget line   |
/// | `over_budget`, `under_budget`      | the hero's status chip           |
/// | `per_budget_over_*`, `per_budget_near_*` | that budget's row in "Other budgets today" |
/// | `per_budget_weekly_over_*`         | nothing: a bill-blind weekly share the engine dropped |
/// | `general`, `no_budget`             | filler / the empty dashboard     |
///
/// New rules show up here automatically, so real insights (streaks,
/// unusual categories) need no change to this widget.
abstract final class HomeInsightFilter {
  static const Set<String> _shownElsewhere = {
    'safe_spend_forecast_short',
    'safe_spend_forecast_ok',
    'budget_progress',
    'over_budget',
    'under_budget',
    'general',
    'no_budget',
  };

  static const List<String> _shownElsewherePrefixes = [
    'per_budget_progress_',
    'per_budget_over_',
    'per_budget_near_',
    'per_budget_weekly_over_',
  ];

  /// At most [limit] insights, the most serious first.
  static List<SmartInsight> visible(
    List<SmartInsight> insights, {
    int limit = 2,
  }) {
    final kept = [
      for (final insight in insights)
        if (!_shownElsewhere.contains(insight.id) &&
            !_shownElsewherePrefixes.any(insight.id.startsWith))
          insight,
    ];
    kept.sort((a, b) => _rank(a.type).compareTo(_rank(b.type)));
    return kept.take(limit).toList();
  }

  static int _rank(InsightType type) => switch (type) {
    InsightType.negative => 0,
    InsightType.warning => 1,
    InsightType.positive => 2,
    InsightType.info => 3,
  };
}

/// The tone an insight is drawn in.
AppTone toneForInsight(InsightType type) => switch (type) {
  InsightType.positive => AppTone.positive,
  InsightType.warning => AppTone.caution,
  InsightType.negative => AppTone.critical,
  InsightType.info => AppTone.info,
};

/// One insight as a quiet line: a tone glyph and the sentence. No tinted
/// card and no "Did you know" title; the icon carries the kind.
class InsightRow extends StatelessWidget {
  final SmartInsight insight;

  const InsightRow({super.key, required this.insight});

  static IconData _icon(InsightType type) => switch (type) {
    InsightType.positive => Icons.check_circle_outline_rounded,
    InsightType.warning => Icons.trending_up_rounded,
    InsightType.negative => Icons.error_outline_rounded,
    InsightType.info => Icons.lightbulb_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: insight.message,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(
                _icon(insight.type),
                size: AppSizes.iconMd,
                color: context.tone(toneForInsight(insight.type)).accent,
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Text(insight.message, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// The insights that are left after [HomeInsightFilter], or nothing at all:
/// on a quiet day the section is absent rather than padded with filler.
class HomeInsightsSection extends StatelessWidget {
  final List<SmartInsight> insights;

  const HomeInsightsSection({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: 'Worth knowing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final insight in insights)
            InsightRow(
              key: ValueKey('insight_${insight.id}'),
              insight: insight,
            ),
        ],
      ),
    );
  }
}
