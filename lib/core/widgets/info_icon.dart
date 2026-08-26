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
      showDragHandle: false,
      builder: (context) => _ExplanationSheet(content: content),
    );
  }
}

// ── Bottom Sheet ─────────────────────────────────────────────────────────────

class _ExplanationSheet extends StatefulWidget {
  final InfoContent content;

  const _ExplanationSheet({required this.content});

  @override
  State<_ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends State<_ExplanationSheet> {
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        controller: _sheetController,
        expand: false,
        minChildSize: 0.25,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.25, 0.55, 0.9],
        builder: (context, scrollController) {
          return Column(
            children: [
              // ── Drag Handle ──
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding > 0 ? AppSpacing.sm : AppSpacing.lg,
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Scrollable Content ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    // ── Title ──
                    Text(
                      'ℹ️  ${widget.content.title}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── What is this? ──
                    _Section(
                      heading: 'What is this?',
                      body: widget.content.whatIsThis,
                    ),

                    // ── How is it calculated? ──
                    if (widget.content.howIsItCalculated != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Section(
                        heading: 'How is it calculated?',
                        body: widget.content.howIsItCalculated!,
                      ),
                    ],

                    // ── Example ──
                    if (widget.content.example != null) ...[
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
                              widget.content.example!,
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
                    if (widget.content.additionalNotes != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Section(
                        heading: 'What affects it?',
                        body: widget.content.additionalNotes!,
                      ),
                    ],

                    // ── Privacy Note ──
                    if (widget.content.privacyNote != null) ...[
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
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.content.privacyNote!,
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
            ],
          );
        },
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
