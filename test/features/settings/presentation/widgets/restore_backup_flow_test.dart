import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/presentation/widgets/restore_backup_flow.dart';

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

  test('a backup without a date or bills still reads plainly', () {
    expect(
      RestoreBackupFlow.describe(
        const BackupSummary(createdAt: null, budgets: 1, expenses: 0, bills: 0),
      ),
      'Backup · 1 budget · 0 expenses · 0 bills',
    );
  });
}
