import 'package:flutter/material.dart';

/// A shimmering placeholder used to build skeleton loading states.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton layout for the dashboard hero + summary while loading.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        // Active budget selector
        SkeletonBox(height: 56, radius: 16),
        SizedBox(height: 16),
        // Hero card
        SkeletonBox(height: 180, radius: 24),
        SizedBox(height: 16),
        // Summary row
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 90, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 90, radius: 16)),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 90, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 90, radius: 16)),
          ],
        ),
        SizedBox(height: 24),
        // Recent expenses skeleton
        SkeletonBox(height: 20, width: 140),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 8),
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 8),
        SkeletonBox(height: 72, radius: 16),
      ],
    );
  }
}

/// Skeleton layout for a list of expense tiles.
class ExpenseListSkeleton extends StatelessWidget {
  final int itemCount;

  const ExpenseListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 80, height: 12),
                ],
              ),
            ),
            SizedBox(width: 12),
            SkeletonBox(width: 60, height: 14),
          ],
        ),
      ),
    );
  }
}
