import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/router/app_page_transitions.dart';

/// A tab body whose State remembers how many times it was mounted and a
/// counter the test bumps, so state loss or a remount is detectable.
class _Tab extends StatefulWidget {
  final String name;
  const _Tab(this.name, {super.key});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  static final Map<String, int> mounts = {};
  int counter = 0;

  @override
  void initState() {
    super.initState();
    mounts[widget.name] = (mounts[widget.name] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Text('${widget.name}:$counter');
}

void main() {
  setUp(_TabState.mounts.clear);

  Widget harness(int index, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FadeThroughBranchContainer(
          currentIndex: index,
          children: const [
            _Tab('home', key: ValueKey('home')),
            _Tab('expenses', key: ValueKey('expenses')),
            _Tab('reports', key: ValueKey('reports')),
            _Tab('settings', key: ValueKey('settings')),
          ],
        ),
      ),
    );
  }

  // Hidden tabs are off stage, so every finder here must look off stage too.
  Finder tab(String name) => find.byKey(ValueKey(name), skipOffstage: false);

  bool isOffstage(WidgetTester tester, String name) {
    final offstage = tester.widget<Offstage>(
      find.ancestor(
        of: tab(name),
        matching: find.byType(Offstage, skipOffstage: false),
      ),
    );
    return offstage.offstage;
  }

  testWidgets('keeps every branch mounted and only shows the current one', (
    tester,
  ) async {
    await tester.pumpWidget(harness(0));
    for (final name in ['home', 'expenses', 'reports', 'settings']) {
      expect(tab(name), findsOneWidget);
      expect(isOffstage(tester, name), name != 'home');
    }
    // Only the current tab is visible.
    expect(find.text('home:0'), findsOneWidget);
    expect(find.text('reports:0'), findsNothing);
  });

  testWidgets('switching tabs preserves each tab\'s State', (tester) async {
    await tester.pumpWidget(harness(0));
    tester.state<_TabState>(tab('home')).counter = 7;

    await tester.pumpWidget(harness(2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness(0));
    await tester.pumpAndSettle();

    expect(tester.state<_TabState>(tab('home')).counter, 7);
    expect(_TabState.mounts['home'], 1);
    expect(_TabState.mounts['reports'], 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('fades the old tab out before the new one fades in', (
    tester,
  ) async {
    await tester.pumpWidget(harness(0));
    await tester.pumpWidget(harness(1));
    await tester.pump();

    double opacityOf(String name) => tester
        .widget<Opacity>(
          find.ancestor(
            of: tab(name),
            matching: find.byType(Opacity, skipOffstage: false),
          ),
        )
        .opacity;

    // Both are on stage during the transition …
    expect(isOffstage(tester, 'home'), isFalse);
    expect(isOffstage(tester, 'expenses'), isFalse);
    // … but the incoming tab waits while the outgoing one fades.
    await tester.pump(const Duration(milliseconds: 40));
    expect(opacityOf('expenses'), 0);
    expect(opacityOf('home'), lessThan(1));

    await tester.pumpAndSettle();
    expect(opacityOf('expenses'), 1);
    expect(isOffstage(tester, 'home'), isTrue);
    expect(isOffstage(tester, 'expenses'), isFalse);
  });

  testWidgets('rapid tab switching settles cleanly on the last tab', (
    tester,
  ) async {
    await tester.pumpWidget(harness(0));
    for (final index in [1, 2, 3, 0, 1]) {
      await tester.pumpWidget(harness(index));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
    expect(isOffstage(tester, 'expenses'), isFalse);
    for (final name in ['home', 'reports', 'settings']) {
      expect(isOffstage(tester, name), isTrue);
    }
    // Nothing was remounted along the way.
    expect(_TabState.mounts.values.every((n) => n == 1), isTrue);
  });

  testWidgets('switches instantly under reduced motion', (tester) async {
    await tester.pumpWidget(harness(0, reduceMotion: true));
    await tester.pumpWidget(harness(3, reduceMotion: true));
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    expect(isOffstage(tester, 'settings'), isFalse);
    expect(isOffstage(tester, 'home'), isTrue);
  });
}
