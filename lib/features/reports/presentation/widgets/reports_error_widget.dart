import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

/// Friendly error state with a retry action.
class ReportsErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ReportsErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: "Couldn't build this report",
      message: message,
      onRetry: onRetry,
    );
  }
}
