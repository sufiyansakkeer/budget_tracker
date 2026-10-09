import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_surface.dart';

/// The current choices at a glance, above the groups: currency, theme,
/// reminders and the app lock, two to a row (four on a wide screen).
class SettingsSummary extends StatelessWidget {
  final String currency;
  final String theme;
  final String reminders;
  final String lock;

  const SettingsSummary({
    super.key,
    required this.currency,
    required this.theme,
    required this.reminders,
    required this.lock,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    final items = [
      ('Currency', currency),
      ('Theme', theme),
      ('Reminders', reminders),
      ('App lock', lock),
    ];
    return AppSurface(
      level: SurfaceLevel.sunken,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.md;
          final perRow = constraints.maxWidth >= 520 ? items.length : 2;
          // Floored so rounding never pushes the last item onto a new run.
          final width = ((constraints.maxWidth - gap * (perRow - 1)) / perRow)
              .floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: AppSpacing.md,
            children: [
              for (final (label, value) in items)
                SizedBox(
                  width: width,
                  child: AppMetric(
                    label: label,
                    value: Text(value, style: style, maxLines: 2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
