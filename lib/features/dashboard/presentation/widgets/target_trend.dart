import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../budget/domain/entities/safe_to_spend/day_target.dart';

/// "How it has moved" (blueprint): each day's target as a line, and what
/// was spent that day as a bar, amber where it went over. From the start
/// of the period to today; nothing with fewer than two days.
class TargetTrend extends StatelessWidget {
  final List<DayTarget> days;
  final String currency;

  const TargetTrend({super.key, required this.days, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (days.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    String whole(double v) => CurrencyFormatter.format(
      v.roundToDouble(),
      code: currency,
      decimalDigits: 0,
    );
    final first = days.first;
    final caption =
        '${whole(first.target)} on ${AppDates.day(first.date)}, '
        '${whole(days.last.target)} today';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'How it has moved',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          caption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: CurrencyFormatter.forSpeech(
            'Daily target from $caption. '
            '${days.where((d) => d.result < 0).length} of ${days.length} '
            'days went over.',
          ),
          excludeSemantics: true,
          child: SizedBox(
            key: const Key('targetTrendChart'),
            height: 120,
            child: CustomPaint(
              painter: _TrendPainter(
                days: days,
                bar: theme.colorScheme.onSurface.withValues(alpha: 0.22),
                over: context.tone(AppTone.caution).accent,
                line: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<DayTarget> days;
  final Color bar;
  final Color over;
  final Color line;

  const _TrendPainter({
    required this.days,
    required this.bar,
    required this.over,
    required this.line,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final top = days.fold<double>(
      0,
      (m, d) => math.max(m, math.max(d.target, d.spent)),
    );
    if (top <= 0) return;
    final slot = size.width / days.length;
    final barWidth = math.max(2.0, slot * 0.55);
    double y(double v) => size.height - v / top * size.height;
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x = slot * i + (slot - barWidth) / 2;
      final within = math.min(d.spent, d.target);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, y(within), x + barWidth, size.height),
          const Radius.circular(2),
        ),
        Paint()..color = bar,
      );
      if (d.spent > d.target) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x, y(d.spent), x + barWidth, y(d.target)),
            const Radius.circular(2),
          ),
          Paint()..color = over,
        );
      }
    }
    final path = Path();
    for (var i = 0; i < days.length; i++) {
      final point = Offset(slot * i + slot / 2, y(days[i].target));
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.days != days ||
      old.bar != bar ||
      old.over != over ||
      old.line != line;
}
