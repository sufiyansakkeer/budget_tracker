import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../constants/app_spacing.dart';

/// Gives a page's scroll view its padding: [padding] plus the side and
/// bottom safe-area insets, widened on a large screen so the content is at
/// most [AppSizes.contentMaxWidth] wide and centred.
///
/// An explicit padding turns off a scroll view's own safe-area padding, so
/// without the insets the last row sits under the home indicator or gesture
/// bar, and the sides under a landscape notch. Insets a Scaffold has
/// already taken (under an app bar, above a bottom bar) read as zero here,
/// so nothing is counted twice. The top is left to the app bar.
///
/// [builder] passes the padding on (a ListView's `padding`, a
/// SliverPadding) rather than this widget narrowing the scroll view, so the
/// whole width still scrolls and the scrollbar stays at the screen edge.
class AppPageBody extends StatelessWidget {
  final EdgeInsets padding;
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  const AppPageBody({
    super.key,
    this.padding = AppSpacing.pagePadding,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // The screen's width rather than a LayoutBuilder's: every page body
    // spans the screen, and a LayoutBuilder would rebuild the whole list on
    // each frame of the keyboard animation, as the body's height changes.
    final width = MediaQuery.sizeOf(context).width;
    final safe = MediaQuery.paddingOf(context);
    final gutter = (width - AppSizes.contentMaxWidth) / 2;
    return builder(
      context,
      EdgeInsets.fromLTRB(
        math.max(padding.left + safe.left, gutter),
        padding.top,
        math.max(padding.right + safe.right, gutter),
        padding.bottom + safe.bottom,
      ),
    );
  }
}
