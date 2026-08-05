import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';

/// Bottom-of-list loader shown while more pages are being fetched.
class LoadingMoreIndicator extends StatelessWidget {
  final bool hasMore;
  final bool isLoading;

  const LoadingMoreIndicator({
    super.key,
    required this.hasMore,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const SizedBox(height: 8);
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}
