import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

/// A key on [AppAmountPad].
sealed class AmountPadKey {
  const AmountPadKey();
}

final class DigitKey extends AmountPadKey {
  final int digit;
  const DigitKey(this.digit);
}

final class DecimalKey extends AmountPadKey {
  const DecimalKey();
}

final class BackspaceKey extends AmountPadKey {
  const BackspaceKey();
}

/// A number pad for entering an amount without the system keyboard.
///
/// Three columns: 1–9, then the decimal point (hidden when the currency has
/// no minor units), 0 and delete. Holding delete clears the amount. Every
/// key is at least 56 dp tall and is announced by name; digits play no
/// haptic, so typing stays quiet.
class AppAmountPad extends StatelessWidget {
  final ValueChanged<AmountPadKey> onKey;
  final VoidCallback onClear;
  final bool showDecimal;

  /// The character for the decimal key ("." or ",").
  final String decimalSeparator;

  const AppAmountPad({
    super.key,
    required this.onKey,
    required this.onClear,
    this.showDecimal = true,
    this.decimalSeparator = '.',
  });

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) =>
        Row(children: [for (final k in keys) Expanded(child: k)]);
    _PadButton digit(int d) => _PadButton(
      key: Key('amountPad_$d'),
      label: '$d',
      onTap: () => onKey(DigitKey(d)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit(1), digit(2), digit(3)]),
        row([digit(4), digit(5), digit(6)]),
        row([digit(7), digit(8), digit(9)]),
        row([
          showDecimal
              ? _PadButton(
                  key: const Key('amountPad_decimal'),
                  label: decimalSeparator,
                  semanticLabel: 'Decimal point',
                  onTap: () => onKey(const DecimalKey()),
                )
              : const SizedBox.shrink(),
          digit(0),
          _PadButton(
            key: const Key('amountPad_backspace'),
            icon: Icons.backspace_outlined,
            semanticLabel: 'Delete',
            tooltip: 'Delete (hold to clear)',
            onTap: () => onKey(const BackspaceKey()),
            onLongPress: onClear,
          ),
        ]),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final String? tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PadButton({
    super.key,
    this.label,
    this.icon,
    this.semanticLabel,
    this.tooltip,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = icon != null
        ? Icon(icon, color: theme.colorScheme.onSurface)
        : Text(
            label!,
            style: context.appTypography.moneyTitle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          );
    Widget button = Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppSpacing.borderRadiusMd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.listRowHeight),
          child: Center(child: content),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}
