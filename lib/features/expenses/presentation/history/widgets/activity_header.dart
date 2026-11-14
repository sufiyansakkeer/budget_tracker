import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import 'activity_switch.dart';

/// The top of both sides of Activity (blueprint `ACT_TOP`): the title with
/// its actions, then the Stream | Insights switch. Stream and Insights use
/// this one widget so switching sides keeps the title, the icons and the
/// switch in place; only what is below them changes.
class ActivityHeader extends StatelessWidget {
  /// Whether Insights is the side on screen.
  final bool insights;

  /// Icon buttons at the end of the title row.
  final List<Widget> actions;

  /// Lines under the title (the budgets viewed together, a caption).
  final List<Widget> below;

  const ActivityHeader({
    super.key,
    required this.insights,
    this.actions = const [],
    this.below = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // With very large text the title shrinks to fit beside
                    // the buttons rather than breaking mid-word.
                    Semantics(
                      header: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'Activity',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    ...below,
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ActivitySwitch(insights: insights),
        ),
      ],
    );
  }
}
