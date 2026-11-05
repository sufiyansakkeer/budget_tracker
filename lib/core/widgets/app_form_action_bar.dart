import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// A form's save bar, for `Scaffold.bottomNavigationBar`.
///
/// Scaffold lays its bottom bar out at the bottom of the screen whatever the
/// keyboard does, so a plain bar sits behind the keyboard. This one pads
/// itself by the keyboard's height, which keeps the primary action in view
/// while the user types; Scaffold then shrinks the body above it. On a
/// tablet the action keeps to the form's centred column (`AppPageBody`).
class AppFormActionBar extends StatelessWidget {
  final Widget child;

  const AppFormActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
