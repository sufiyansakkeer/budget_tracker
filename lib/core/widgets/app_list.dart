import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/app_spacing.dart';
import '../currency/currency_formatter.dart';

/// One row of a list: optional leading tile, a title with an optional
/// subtitle, and an optional trailing widget (an amount, a switch, a
/// chevron).
///
/// At least 56 dp tall, with the whole row as the touch target. When
/// [onTap] is set the row is one button for screen readers, labelled with
/// [semanticLabel] or, by default, the title and subtitle. Money in the
/// label is spoken with its currency ([CurrencyFormatter.forSpeech]).
class AppListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Replaces [subtitle] when the second line needs styling of its own.
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// What a long press does, read by screen readers ("more actions").
  final String? longPressHint;

  /// Colour for the title, e.g. a destructive action.
  final Color? titleColor;

  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.longPressHint,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactive = onTap != null || onLongPress != null;
    final second =
        subtitleWidget ??
        (subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ));

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.listRowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: _TrailingCapRow(
          body: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.smd),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (second != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      second,
                    ],
                  ],
                ),
              ),
            ],
          ),
          trailing: trailing,
        ),
      ),
    );

    final spoken = semanticLabel == null
        ? null
        : CurrencyFormatter.forSpeech(semanticLabel!);
    if (!interactive) {
      return spoken == null
          ? MergeSemantics(child: row)
          : Semantics(label: spoken, excludeSemantics: true, child: row);
    }
    return Semantics(
      button: true,
      label:
          spoken ?? CurrencyFormatter.forSpeech([title, ?subtitle].join(', ')),
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : longPressHint,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppSpacing.borderRadiusSm,
        child: row,
      ),
    );
  }
}

/// [body] beside an optional [trailing] widget (an amount), which may take
/// up to 46% of this row's own width and then scales down, so the title
/// always keeps room at large text sizes. Measured from the row rather than
/// the screen, so a row in a centred tablet column caps like one on a
/// phone; a render object rather than a LayoutBuilder, so the row still
/// works inside dialogs that measure intrinsics.
class _TrailingCapRow extends MultiChildRenderObjectWidget {
  _TrailingCapRow({required Widget body, Widget? trailing})
    : super(children: [body, ?trailing]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTrailingCapRow(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTrailingCapRow renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _CapParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out like the `Row` it replaced: the body fills what the trailing
/// widget leaves, both centred vertically, the trailing widget at the end.
class _RenderTrailingCapRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CapParentData> {
  _RenderTrailingCapRow(this._textDirection);

  /// 46% of the row: on a 360 dp phone page (16 dp margins) that is the
  /// 42% of the screen the row used to measure, so phones are unchanged.
  static const double _share = 0.46;
  static const double _gap = AppSpacing.smd;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _body => firstChild!;
  RenderBox? get _trailing => childAfter(firstChild!);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CapParentData) {
      child.parentData = _CapParentData();
    }
  }

  double _widthOf(double Function(RenderBox child) of) {
    final trailing = _trailing;
    return of(_body) + (trailing == null ? 0 : _gap + of(trailing));
  }

  double _heightAt(double width, double Function(RenderBox, double) of) {
    final trailing = _trailing;
    if (trailing == null) return of(_body, width);
    final wanted = trailing.getMaxIntrinsicWidth(double.infinity);
    final side = width.isFinite ? math.min(wanted, width * _share) : wanted;
    final body = width.isFinite
        ? math.max(0.0, width - _gap - side)
        : double.infinity;
    return math.max(of(_body, body), of(trailing, side));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _widthOf((child) => child.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _widthOf((child) => child.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightAt(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightAt(width, (child, w) => child.getMaxIntrinsicHeight(w));

  ({Size size, Size body, Size? trailing}) _layout(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final width = constraints.maxWidth;
    final trailing = _trailing;
    final trailingSize = trailing == null
        ? null
        : layoutChild(
            trailing,
            BoxConstraints(
              maxWidth: width.isFinite ? width * _share : double.infinity,
              maxHeight: constraints.maxHeight,
            ),
          );
    final used = trailingSize == null ? 0.0 : _gap + trailingSize.width;
    final bodyWidth = math.max(0.0, width - used);
    final bodySize = layoutChild(
      _body,
      width.isFinite
          ? BoxConstraints(
              minWidth: bodyWidth,
              maxWidth: bodyWidth,
              maxHeight: constraints.maxHeight,
            )
          : BoxConstraints(maxHeight: constraints.maxHeight),
    );
    final height = math.max(bodySize.height, trailingSize?.height ?? 0);
    return (
      size: constraints.constrain(Size(bodySize.width + used, height)),
      body: bodySize,
      trailing: trailingSize,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final laid = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = laid.size;
    final rtl = _textDirection == TextDirection.rtl;
    (_body.parentData! as _CapParentData).offset = Offset(
      rtl ? size.width - laid.body.width : 0,
      (size.height - laid.body.height) / 2,
    );
    final trailing = _trailing;
    final trailingSize = laid.trailing;
    if (trailing != null && trailingSize != null) {
      (trailing.parentData! as _CapParentData).offset = Offset(
        rtl ? 0 : size.width - trailingSize.width,
        (size.height - trailingSize.height) / 2,
      );
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Rows separated by hairlines, with no card around them.
///
/// The divider starts after the leading tile ([dividerIndent]) so the rows
/// read as one list. Set [filled] for a grouped list on its own surface
/// (Settings), which adds a fill, padding and the object-card radius.
class AppGroupedList extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  final bool filled;

  const AppGroupedList({
    super.key,
    required this.children,
    this.dividerIndent = 0,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              indent: dividerIndent,
              color: theme.colorScheme.outlineVariant,
            ),
          children[i],
        ],
      ],
    );
    if (!filled) return column;
    // A Material rather than a decorated box, so row ink shows on the fill
    // and is clipped to its corners.
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: column,
      ),
    );
  }
}
