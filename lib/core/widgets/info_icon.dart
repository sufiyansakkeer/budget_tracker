import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors_extension.dart';
import 'app_bottom_sheet.dart';
import 'info_content.dart';

/// A subtle ⓘ button that opens an explanation bottom sheet.
///
/// Drop this widget beside any section title or metric to give users
/// contextual help without cluttering the UI. The visual icon is small but
/// the tap target meets the 48 dp minimum.
class InfoIcon extends StatelessWidget {
  /// The explanation content displayed when tapped.
  final InfoContent content;

  /// Icon color override (defaults to a muted on-surface tone).
  final Color? color;

  const InfoIcon({super.key, required this.content, this.color});

  /// Opens the explanation sheet for [content] from any context.
  static Future<void> showSheet(BuildContext context, InfoContent content) {
    return AppBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ExplanationSheet(content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: () => showSheet(context, content),
      tooltip: 'About ${content.title}',
      visualDensity: VisualDensity.compact,
      iconSize: AppSizes.iconSm + 2,
      icon: Icon(
        Icons.info_outline_rounded,
        color: color ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ── Bottom Sheet ─────────────────────────────────────────────────────────────

class _ExplanationSheet extends StatelessWidget {
  final InfoContent content;

  const _ExplanationSheet({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_rounded,
                  size: AppSizes.iconMd,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      content.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            _Section(heading: 'What is this?', body: content.whatIsThis),

            if (content.howIsItCalculated != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _Section(
                heading: 'How is it calculated?',
                body: content.howIsItCalculated!,
              ),
            ],

            if (content.example != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Example',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      content.example!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (content.additionalNotes != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _Section(heading: 'Good to know', body: content.additionalNotes!),
            ],

            if (content.privacyNote != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: AppSizes.iconSm,
                    color: appColors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      content.privacyNote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String heading;
  final String body;

  const _Section({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
