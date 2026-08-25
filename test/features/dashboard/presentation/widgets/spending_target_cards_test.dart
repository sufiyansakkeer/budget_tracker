import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/presentation/widgets/spending_target_cards.dart';

SpendingTargetEntity _buildTarget({
  double dailyTarget = 1250,
  double dailySpent = 850,
  SpendingTargetStatus dailyStatus = SpendingTargetStatus.onTrack,
  double weeklyTarget = 8750,
  double weeklySpent = 6400,
  SpendingTargetStatus weeklyStatus = SpendingTargetStatus.onTrack,
  String currency = 'INR',
}) {
  final dailyRemaining = (dailyTarget - dailySpent).clamp(0.0, double.infinity);
  final dailyExceeded =
      dailySpent > dailyTarget ? dailySpent - dailyTarget : 0.0;
  final dailyProgress =
      dailyTarget > 0 ? (dailySpent / dailyTarget).clamp(0.0, 1.0) : 0.0;

  final weeklyRemaining =
      (weeklyTarget - weeklySpent).clamp(0.0, double.infinity);
  final weeklyExceeded =
      weeklySpent > weeklyTarget ? weeklySpent - weeklyTarget : 0.0;
  final weeklyProgress =
      weeklyTarget > 0 ? (weeklySpent / weeklyTarget).clamp(0.0, 1.0) : 0.0;

  return SpendingTargetEntity(
    dailyTarget: dailyTarget,
    dailySpent: dailySpent,
    dailyRemaining: dailyRemaining,
    dailyExceeded: dailyExceeded,
    dailyProgress: dailyProgress,
    dailyStatus: dailyStatus,
    weeklyTarget: weeklyTarget,
    weeklySpent: weeklySpent,
    weeklyRemaining: weeklyRemaining,
    weeklyExceeded: weeklyExceeded,
    weeklyProgress: weeklyProgress,
    weeklyStatus: weeklyStatus,
    currency: currency,
  );
}

Widget wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('DailyTargetCard', () {
    testWidgets('renders on-track state correctly', (tester) async {
      final target = _buildTarget(
        dailyTarget: 1250,
        dailySpent: 850,
        dailyStatus: SpendingTargetStatus.onTrack,
      );

      await tester.pumpWidget(wrap(DailyTargetCard(targets: target)));

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('₹1,250'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('Exceeded'), findsNothing);
    });

    testWidgets('renders exceeded state correctly', (tester) async {
      final target = _buildTarget(
        dailyTarget: 1250,
        dailySpent: 1700,
        dailyStatus: SpendingTargetStatus.exceeded,
      );

      await tester.pumpWidget(wrap(DailyTargetCard(targets: target)));

      expect(find.text('₹1,250'), findsOneWidget);
      expect(find.text('Exceeded by'), findsOneWidget);
      expect(find.text('Over Target'), findsOneWidget);
      expect(find.text('Remaining'), findsNothing);
    });

    testWidgets('renders near-limit state correctly', (tester) async {
      final target = _buildTarget(
        dailyTarget: 1250,
        dailySpent: 1100,
        dailyStatus: SpendingTargetStatus.nearLimit,
      );

      await tester.pumpWidget(wrap(DailyTargetCard(targets: target)));

      expect(find.text('Near Limit'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
    });
  });

  group('WeeklyTargetCard', () {
    testWidgets('renders on-track state correctly', (tester) async {
      final target = _buildTarget(
        weeklyTarget: 8750,
        weeklySpent: 6400,
        weeklyStatus: SpendingTargetStatus.onTrack,
      );

      await tester.pumpWidget(wrap(WeeklyTargetCard(targets: target)));

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('₹8,750'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
    });

    testWidgets('renders exceeded state correctly', (tester) async {
      final target = _buildTarget(
        weeklyTarget: 8750,
        weeklySpent: 9500,
        weeklyStatus: SpendingTargetStatus.exceeded,
      );

      await tester.pumpWidget(wrap(WeeklyTargetCard(targets: target)));

      expect(find.text('₹8,750'), findsOneWidget);
      expect(find.text('Exceeded by'), findsOneWidget);
      expect(find.text('Over Target'), findsOneWidget);
    });
  });

  group('Both cards together', () {
    testWidgets('renders both daily and weekly targets', (tester) async {
      final target = _buildTarget();

      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              DailyTargetCard(targets: target),
              const SizedBox(height: 8),
              WeeklyTargetCard(targets: target),
            ],
          ),
        ),
      );

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      // Target amounts
      expect(find.text('₹1,250'), findsOneWidget);
      expect(find.text('₹8,750'), findsOneWidget);
    });
  });
}
