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
    if (!hasMore || !isLoading) {
      return const SizedBox(height: AppSpacing.sm);
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: AppSizes.iconLg,
          height: AppSizes.iconLg,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
