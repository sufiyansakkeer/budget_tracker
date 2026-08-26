import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'app_bottom_sheet.dart';
import 'info_content.dart';

/// A subtle ⓘ icon that opens an explanation bottom sheet.
///
/// Drop this widget beside any section title or metric to give users
/// contextual help without cluttering the UI.
class InfoIcon extends StatelessWidget {
  /// The explanation content displayed when tapped.
  final InfoContent content;

  const InfoIcon({super.key, required this.content});

  /// Convenience: tap anywhere on this widget opens the sheet.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Learn more about ${content.title}',
      button: true,
      child: InkWell(
        onTap: () => _showExplanation(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _ExplanationSheet(content: content),
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
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title ──
              Text(
                'ℹ️  ${content.title}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── What is this? ──
              _Section(heading: 'What is this?', body: content.whatIsThis),

              // ── How is it calculated? ──
              if (content.howIsItCalculated != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  heading: 'How is it calculated?',
                  body: content.howIsItCalculated!,
                ),
              ],

              // ── Example ──
              if (content.example != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Example',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        content.example!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Additional Notes ──
              if (content.additionalNotes != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  heading: 'What affects it?',
                  body: content.additionalNotes!,
                ),
              ],

              // ── Privacy Note ──
              if (content.privacyNote != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          content.privacyNote!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
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
        Text(
          heading,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
