import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/presentation/widgets/restore_backup_flow.dart';
import 'package:monivo/core/dates/date_range_format.dart';

/// UX-041: the Restore question said nothing about the picked file.
void main() {
  const summary = BackupSummary(
    createdAt: null,
    budgets: 3,
    expenses: 412,
    bills: 1,
  );

  Future<({String? path, String? refused})> run(
    WidgetTester tester,
    SettingsResult<BackupSummary> preview, {
    bool confirm = true,
  }) async {
    String? path;
    String? refused;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              path = await RestoreBackupFlow.pickAndConfirm(
                context,
                pickFile: () async => '/picked.json',
                preview: (_) async => preview,
                onRefused: (message) => refused = message,
              );
              done = true;
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    if (!done) {
      await tester.tap(find.text(confirm ? 'Restore' : 'Cancel'));
      await tester.pumpAndSettle();
    }
    return (path: path, refused: refused);
  }

  testWidgets('the question says what the backup holds', (tester) async {
    String? path;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                path = await RestoreBackupFlow.pickAndConfirm(
                  context,
                  pickFile: () async => '/picked.json',
                  preview: (_) async => SettingsSuccess(
                    BackupSummary(
                      createdAt: DateTime(2026, 10, 3, 14, 30),
                      budgets: 3,
                      expenses: 412,
                      bills: 2,
                    ),
                  ),
                  onRefused: (_) {},
                ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(
      find.textContaining(
        'Backup from 3 Oct 2026, 2:30 PM · 3 budgets · 412 expenses · 2 bills',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(path, '/picked.json');
  });

  testWidgets('cancelling restores nothing', (tester) async {
    final r = await run(tester, const SettingsSuccess(summary), confirm: false);
    expect(r.path, isNull);
    expect(r.refused, isNull);
  });

  testWidgets('a file that is not a backup is refused before the question', (
    tester,
  ) async {
    final r = await run(
      tester,
      const SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message: 'Backup validation failed',
        ),
      ),
    );

    expect(find.text('Restore this backup?'), findsNothing);
    expect(r.path, isNull);
    expect(r.refused, contains('Nothing was changed.'));
  });

  Future<BuildContext> contextFor(
    WidgetTester tester, {
    bool use24h = false,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: use24h),
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('a backup without a date or bills still reads plainly', (
    tester,
  ) async {
    final context = await contextFor(tester);
    expect(
      RestoreBackupFlow.describe(
        context,
        const BackupSummary(createdAt: null, budgets: 1, expenses: 0, bills: 0),
      ),
      'Backup · 1 budget · 0 expenses · 0 bills',
    );
  });

  testWidgets('UX-093: the backup time follows the 24-hour setting', (
    tester,
  ) async {
    final createdAt = DateTime(2026, 10, 3, 14, 30);
    final context = await contextFor(tester, use24h: true);
    final text = RestoreBackupFlow.describe(
      context,
      BackupSummary(createdAt: createdAt, budgets: 1, expenses: 0, bills: 0),
    );
    expect(
      text,
      startsWith('Backup from ${AppDates.dateTime(context, createdAt)}'),
    );
    expect(text, contains(TimeOfDay.fromDateTime(createdAt).format(context)));
    expect(text, isNot(contains('PM')));
  });
  group('UX-109: the restore holds the app until it ends', () {
    Future<Completer<void>> start(WidgetTester tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  RestoreBackupFlow.showProgressUntil(context, done.future),
              child: const Text('restore'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('restore'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return done;
    }

    final dialog = find.byKey(const Key('restoreProgressDialog'));

    testWidgets('Back and the barrier leave it up; the end closes it', (
      tester,
    ) async {
      final done = await start(tester);
      expect(dialog, findsOneWidget);
      expect(
        find.text('Restoring your backup… Keep Monivo open.'),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialog, findsOneWidget);
      expect(find.text('restore').hitTestable(), findsNothing);

      done.complete();
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.text('restore').hitTestable(), findsOneWidget);
    });

    testWidgets('a failed wait still closes it', (tester) async {
      final done = await start(tester);
      done.completeError(StateError('No element'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });
  });
}
