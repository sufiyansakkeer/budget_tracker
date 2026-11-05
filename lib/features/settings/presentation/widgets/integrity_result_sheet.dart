import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/services/database_integrity_service.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/dates/date_range_format.dart';

/// Shows the outcome of a database integrity check.
abstract final class IntegrityResultSheet {
  static Future<void> show(BuildContext context, IntegrityCheckResult result) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) => _IntegrityResultBody(result: result),
    );
  }
}

class _IntegrityResultBody extends StatelessWidget {
  final IntegrityCheckResult result;

  const _IntegrityResultBody({required this.result});

  static const int _maxListed = 25;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issues = result.issues;
    final checkedAt = AppDates.dateTime(context, result.checkedAt);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: 'Database check', subtitle: 'Ran $checkedAt'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: result.passed
                ? AppNotice(
                    key: const Key('integrityPassed'),
                    tone: AppTone.positive,
                    icon: Icons.verified_rounded,
                    title: 'Everything looks good',
                    message:
                        'Budgets, expenses, bills and their links are all '
                        'consistent.',
                  )
                : AppNotice(
                    key: const Key('integrityIssues'),
                    tone: AppTone.caution,
                    icon: Icons.report_problem_rounded,
                    title:
                        '${issues.length} ${issues.length == 1 ? 'issue' : 'issues'} found',
                    // No promise the app can't keep: a restore brings back
                    // the same records, and only some can be edited here.
                    message:
                        'The app keeps working. Back up first, so nothing is '
                        'lost. Each issue below says where to fix it, when '
                        'the app can.',
                  ),
          ),
          if (!result.passed) ...[
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                itemCount:
                    issues.length.clamp(0, _maxListed) +
                    (issues.length > _maxListed ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _maxListed) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        '…and ${issues.length - _maxListed} more',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  final issue = issues[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(issue.description),
                    subtitle: Text(
                      [_recordLabel(issue), ?_whereToFix(issue)].join('\n'),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Where the user can correct [issue] in the app, or null when no screen
/// can (an expense whose budget is gone is listed nowhere).
String? _whereToFix(IntegrityIssue issue) => switch (issue.table) {
  'budgets' => 'Fix it from Budgets: open the budget and edit it.',
  'bills' => 'Fix it from Bills: open the bill and edit it.',
  _ => null,
};

/// "Expense · 3f2a9c1e": the kind of record in words and the start of its
/// id, instead of the table name and the full id.
String _recordLabel(IntegrityIssue issue) {
  final kind = switch (issue.table) {
    'expenses' => 'Expense',
    'budgets' => 'Budget',
    'bills' => 'Bill',
    'billPayments' => 'Bill payment',
    'recurringExpenses' => 'Recurring expense',
    final other => other,
  };
  final id = issue.entityId;
  return '$kind · ${id.length > 8 ? id.substring(0, 8) : id}';
}
