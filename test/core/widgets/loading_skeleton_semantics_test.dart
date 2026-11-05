import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/loading_skeleton.dart';

// UX-106: skeletons were silent to screen readers. Each loading region is
// now one live "Loading …" node; the bones inside it say nothing.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  testWidgets('a region is one live node, announced when it appears', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const Shimmer(
          semanticsLabel: 'Loading bills',
          child: Column(
            children: [
              SkeletonListTile(),
              SkeletonListTile(),
              SkeletonListTile(),
            ],
          ),
        ),
      ),
    );
    // Before the 300 ms reveal there is nothing to announce.
    expect(find.bySemanticsLabel('Loading bills'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    final nodes = find.bySemanticsLabel('Loading bills');
    expect(nodes, findsOneWidget);
    final data = tester.getSemantics(nodes).getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    handle.dispose();
  });

  testWidgets('the named skeletons say what is loading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const ExpenseListSkeleton()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Loading expenses'), findsOneWidget);

    await tester.pumpWidget(host(const DashboardSkeleton()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Loading Home'), findsOneWidget);

    await tester.pumpWidget(host(const FormSkeleton()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    handle.dispose();
  });
}
