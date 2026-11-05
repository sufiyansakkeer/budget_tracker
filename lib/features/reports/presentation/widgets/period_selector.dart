import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../domain/entities/report_period.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/constants/app_copy.dart';

/// The one place a report's dates are chosen: "This Budget" (the active
/// budget's own period), the calendar presets and Custom. The filter sheet
/// on Reports offers no dates, so the range shown is always the range used.
///
/// The chosen chip is always scrolled into view: on a phone "This Month"
/// starts past the right edge, so the choice read as cut off (UX-085).
class PeriodSelector extends StatefulWidget {
  final ReportPeriod selected;

  /// Whether "This Budget" is the current choice; the report then uses a
  /// custom range under the hood, which must not light up "Custom".
  final bool followsBudget;
  final ValueChanged<ReportPeriod> onSelected;

  /// Chooses "This Budget"; null hides the chip.
  final VoidCallback? onBudget;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.followsBudget = false,
    this.onBudget,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  static const Object _budget = 'thisBudget';

  final ScrollController _scroll = ScrollController();
  final Map<Object, GlobalKey> _keys = {};

  GlobalKey _keyFor(Object chip) => _keys.putIfAbsent(chip, GlobalKey.new);

  Object _chosen(PeriodSelector w) =>
      w.followsBudget && w.onBudget != null ? _budget : w.selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(false));
  }

  @override
  void didUpdateWidget(covariant PeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_chosen(oldWidget) != _chosen(widget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(true));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls just far enough to show the chosen chip whole; a chip already
  /// in view does not move the row.
  void _reveal(bool animate) {
    if (!mounted || !_scroll.hasClients) return;
    final chip = _keys[_chosen(widget)]?.currentContext?.findRenderObject();
    if (chip == null || !chip.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(chip);
    if (viewport == null) return;
    final position = _scroll.position;
    final atStart = viewport.getOffsetToReveal(chip, 0).offset;
    final atEnd = viewport.getOffsetToReveal(chip, 1).offset;
    final target = position.pixels
        .clamp(math.min(atStart, atEnd), math.max(atStart, atEnd))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    if (!animate || duration == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: duration, curve: AppMotion.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('periodSelectorScroll'),
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (widget.onBudget != null)
            Padding(
              key: _keyFor(_budget),
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                key: const Key('period_thisBudget'),
                label: const Text('This budget'),
                avatar: const Icon(Icons.account_balance_wallet_outlined),
                showCheckmark: false,
                selected: widget.followsBudget,
                onSelected: (_) {
                  AppHaptics.selection();
                  widget.onBudget!();
                },
              ),
            ),
          for (final period in ReportPeriod.values)
            Padding(
              key: _keyFor(period),
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                key: Key('period_${period.name}'),
                label: Text(AppTerms.sentenceCase(period.label)),
                avatar: period.isCustom
                    ? const Icon(Icons.date_range_rounded)
                    : null,
                showCheckmark: false,
                selected: !widget.followsBudget && period == widget.selected,
                onSelected: (_) {
                  AppHaptics.selection();
                  widget.onSelected(period);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the resolved date range for the current report, so a preset and a
/// custom range are equally clear. Tapping opens the custom range picker.
class ReportRangeLabel extends StatelessWidget {
  final ReportRange range;
  final VoidCallback onEdit;

  const ReportRangeLabel({
    super.key,
    required this.range,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = range.dayCount;
    final dates =
        '${AppDates.range(range.start, range.end)} · '
        '$days ${days == 1 ? 'day' : 'days'}';
    // One 48 dp button read as "Report period …, change" (UX-061).
    return Semantics(
      button: true,
      label:
          'Report period ${AppDates.range(range.start, range.end)}, '
          '$days ${days == 1 ? 'day' : 'days'}. Change',
      excludeSemantics: true,
      child: InkWell(
        onTap: onEdit,
        borderRadius: AppSpacing.borderRadiusSm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: AppSizes.iconXs,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  // Two lines at large text rather than cutting the year.
                  child: Text(
                    dates,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Change',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
