import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../quick_add/quick_add_sheet.dart';

/// What the bar's + opens (blueprint): every way money moves, as a 2 × 2
/// grid with the everyday expense filled. Holding + skips this and opens
/// quick add straight away.
class AddSheet extends StatelessWidget {
  const AddSheet({super.key});

  /// Opens quick add; replaced in tests.
  @visibleForTesting
  static Future<void> Function(BuildContext) openQuickAdd = QuickAddSheet.show;

  @visibleForTesting
  static void resetQuickAdd() => openQuickAdd = QuickAddSheet.show;

  static const _quickAdd = 'quick';

  /// Shows the sheet; the chosen screen opens once it has closed.
  static Future<void> show(BuildContext context) async {
    final choice = await AppBottomSheet.show<String>(
      context: context,
      builder: (_) => const AddSheet(),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _quickAdd) {
      await openQuickAdd(context);
    } else {
      await context.pushUnique(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget tile(
      String key,
      String id,
      IconData icon,
      String title,
      String line, {
      bool main = false,
    }) {
      final ink = main ? scheme.onPrimaryContainer : scheme.onSurface;
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      );
      return Semantics(
        button: true,
        label: '$title, $line',
        excludeSemantics: true,
        child: Material(
          key: Key(key),
          color: main ? scheme.primaryContainer : scheme.surfaceContainer,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: () => Navigator.of(context).pop(id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 116),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: ink),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: main ? ink : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget pair(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Add', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.md),
            pair(
              tile(
                'addSheet_expense',
                _quickAdd,
                Icons.receipt_long_rounded,
                'Expense',
                'Spent money now',
                main: true,
              ),
              tile(
                'addSheet_bill',
                '/app/bills/add',
                Icons.event_outlined,
                'Bill',
                'Something due later',
              ),
            ),
            const SizedBox(height: 10),
            pair(
              tile(
                'addSheet_onTab',
                '/app/expenses/add?payLater=1',
                Icons.local_cafe_outlined,
                'On a tab',
                'Bought now, pay later',
              ),
              tile(
                'addSheet_tabPayment',
                '/app/pay-later',
                Icons.toll_outlined,
                'Tab payment',
                'Paid off some of a tab',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
