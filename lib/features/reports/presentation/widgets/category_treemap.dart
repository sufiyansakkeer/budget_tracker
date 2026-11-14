import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/category_analytics.dart';

/// Splits [area] into one rectangle per value, each with the value's share
/// of the area: the first value takes its share along the longer side and
/// the rest are laid out the same way in what remains. Values are drawn in
/// the order given (largest first reads best). Empty when nothing is above
/// zero.
List<Rect> treemapLayout(List<double> values, Rect area) {
  final total = values.fold<double>(0, (sum, v) => sum + (v > 0 ? v : 0));
  if (total <= 0) return const [];
  final rects = <Rect>[];
  var rest = area;
  var remaining = total;
  for (var i = 0; i < values.length; i++) {
    final v = values[i] > 0 ? values[i] : 0.0;
    if (i == values.length - 1 || remaining <= 0) {
      rects.add(rest);
      break;
    }
    final share = v / remaining;
    if (rest.width >= rest.height) {
      final w = rest.width * share;
      rects.add(Rect.fromLTWH(rest.left, rest.top, w, rest.height));
      rest = Rect.fromLTWH(
        rest.left + w,
        rest.top,
        rest.width - w,
        rest.height,
      );
    } else {
      final h = rest.height * share;
      rects.add(Rect.fromLTWH(rest.left, rest.top, rest.width, h));
      rest = Rect.fromLTWH(
        rest.left,
        rest.top + h,
        rest.width,
        rest.height - h,
      );
    }
    remaining -= v;
  }
  return rects;
}

/// Where the money went, as areas: one block per category in its own
/// colour, sized by its share. The six largest get a block each; the rest
/// share "Other". A picture of the ranking below it, which carries the
/// figures and the taps, so it is not read out.
class CategoryTreemap extends StatelessWidget {
  final List<CategoryAnalytics> analytics;
  final String currency;

  const CategoryTreemap({
    super.key,
    required this.analytics,
    required this.currency,
  });

  static const int _blocks = 6;
  // Blueprint .tm: 220 high.
  static const double _height = 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ranked = [...analytics]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final top = ranked.take(_blocks).toList();
    final otherAmount = ranked
        .skip(_blocks)
        .fold<double>(0, (sum, a) => sum + a.totalAmount);
    String line(double amount, double? pct) =>
        '${AppMoney.format(amount, currency: currency)}'
        '${pct == null ? '' : ' · ${pct.round()}%'}';
    final total = ranked.fold<double>(0, (sum, a) => sum + a.totalAmount);
    final blocks = [
      for (final a in top)
        (
          'treemap_${a.categoryId}',
          a.categoryName,
          a.totalAmount,
          CategoryVisuals.adaptiveColor(context, a.colorHex),
          line(a.totalAmount, a.percentageOfTotal),
        ),
      if (otherAmount > 0)
        (
          'treemap_other',
          '+${ranked.length - _blocks}',
          otherAmount,
          theme.colorScheme.outline,
          line(otherAmount, total > 0 ? otherAmount / total * 100 : null),
        ),
    ];

    return ExcludeSemantics(
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rects = treemapLayout([
              for (final b in blocks) b.$3,
            ], Offset.zero & Size(constraints.maxWidth, _height));
            return Stack(
              children: [
                for (var i = 0; i < rects.length; i++)
                  Positioned.fromRect(
                    key: Key(blocks[i].$1),
                    rect: rects[i],
                    child: _Block(
                      label: blocks[i].$2,
                      line: blocks[i].$5,
                      color: blocks[i].$4,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final String line;
  final Color color;

  const _Block({required this.label, required this.line, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Blueprint .tb2: the category's colour at 20% on the card, the name
    // in ink at the top and its share in secondary ink at the foot.
    final fill = Color.alphaBlend(
      color.withValues(alpha: 0.2),
      theme.cardTheme.color ?? theme.colorScheme.surface,
    );
    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppSpacing.borderRadiusSm,
        ),
        child: LayoutBuilder(
          builder: (context, c) => c.maxWidth < 56 || c.maxHeight < 28
              ? const SizedBox.expand()
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Large text shrinks to the block rather than spilling.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.topStart,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (c.maxHeight >= 48)
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.bottomStart,
                            child: Text(
                              line,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
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
