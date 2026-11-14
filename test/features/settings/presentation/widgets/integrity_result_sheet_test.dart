import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/services/database_integrity_service.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/settings/presentation/widgets/integrity_result_sheet.dart';

/// UX-102: the sheet promised a restore would clear the issues and gave no
/// way to act on them.
void main() {
  Future<void> showSheet(
    WidgetTester tester,
    List<IntegrityIssue> issues,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => IntegrityResultSheet.show(
                context,
                IntegrityCheckResult(
                  passed: issues.isEmpty,
                  issues: issues,
                  checkedAt: DateTime(2026, 11, 5, 9, 30),
                ),
              ),
              child: const Text('Check'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
  }

  testWidgets('no restore promise; each issue says where to fix it', (
    tester,
  ) async {
    await showSheet(tester, const [
      IntegrityIssue(
        table: 'budgets',
        description: 'Budget ends before it starts',
        entityId: 'budget-123456789',
      ),
      IntegrityIssue(
        table: 'bills',
        description: 'Bill has invalid amount: -5',
        entityId: 'bill-123456789',
      ),
      IntegrityIssue(
        table: 'expenses',
        description: 'Expense references a missing budget',
        entityId: 'expense-123456789',
      ),
    ]);

    expect(find.text('3 issues found'), findsOneWidget);
    expect(find.textContaining('Restoring'), findsNothing);
    expect(find.textContaining('restore'), findsNothing);
    expect(find.textContaining('Fix it from Budgets'), findsOneWidget);
    expect(find.textContaining('Fix it from Bills'), findsOneWidget);
    // An expense whose budget is gone can't be opened anywhere: no hint.
    expect(find.text('Expense · expense-'), findsOneWidget);
  });

  testWidgets('a clean check says so', (tester) async {
    await showSheet(tester, const []);
    expect(find.text('Everything looks good'), findsOneWidget);
  });
}
