import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "Stream | Insights" under Activity's title (blueprint): the history and
/// the report on it, one switch apart. Each side is its own screen.
class ActivitySwitch extends StatelessWidget {
  /// Whether Insights is the side on screen.
  final bool insights;

  const ActivitySwitch({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Stream')),
          ButtonSegment(value: true, label: Text('Insights')),
        ],
        selected: {insights},
        onSelectionChanged: (choice) {
          if (choice.single == insights) return;
          context.go(choice.single ? '/app/reports' : '/app/expenses');
        },
      ),
    );
  }
}
