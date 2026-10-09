import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';
import 'app_animated_size.dart';

/// Optional fields folded under one row ("More options"), so a form shows
/// what has to be decided first and the rest on request.
///
/// Collapsed, the row says what is inside ([summary]); a tap opens it in
/// place. The fields keep their values while folded, because their
/// controllers live in the form. Screen readers hear it as an expandable
/// button.
class AppDisclosure extends StatefulWidget {
  final String title;

  /// What is folded away, e.g. "Category, repeat, reminder and note".
  final String? summary;
  final bool initiallyExpanded;
  final Widget child;

  const AppDisclosure({
    super.key,
    required this.title,
    this.summary,
    this.initiallyExpanded = false,
    required this.child,
  });

  @override
  State<AppDisclosure> createState() => _AppDisclosureState();
}

class _AppDisclosureState extends State<AppDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.respectReducedMotion(context, AppMotion.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: widget.title,
          hint: widget.summary,
          excludeSemantics: true,
          onTap: _toggle,
          child: InkWell(
            onTap: _toggle,
            borderRadius: AppSpacing.borderRadiusSm,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.title, style: theme.textTheme.titleSmall),
                          if (widget.summary != null && !_expanded)
                            Text(
                              widget.summary!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: duration,
                      curve: AppMotion.standardCurve,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AppAnimatedSize(
          duration: duration,
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  void _toggle() => setState(() => _expanded = !_expanded);
}
