import 'package:flutter/material.dart';

import '../../../../../core/widgets/empty_state.dart';

/// Friendly error state with a retry action.
class ExpenseHistoryErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ExpenseHistoryErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      key: const Key('historyRetry'),
      title: "Couldn't load expenses",
      message: message,
      retryLabel: 'Retry',
      onRetry: onRetry,
    );
  }
}
