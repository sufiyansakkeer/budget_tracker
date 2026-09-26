import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/services/database_integrity_service.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';

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
    final colors = context.appColors;
    final issues = result.issues;
    final checkedAt = DateFormat('d MMM yyyy, h:mm a').format(result.checkedAt);

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
                ? StatusCard(
                    key: const Key('integrityPassed'),
                    color: colors.success,
                    icon: Icons.verified_rounded,
                    title: 'Everything looks good',
                    message:
                        'Budgets, expenses, bills and their links are all '
                        'consistent.',
                  )
                : StatusCard(
                    key: const Key('integrityIssues'),
                    color: colors.warning,
                    icon: Icons.report_problem_rounded,
                    title:
                        '${issues.length} ${issues.length == 1 ? 'issue' : 'issues'} found',
                    message:
                        'The app keeps working, but a backup is recommended '
                        'before you tidy these up. Restoring a recent backup '
                        'usually clears them.',
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
                    subtitle: Text('${issue.table} · ${issue.entityId}'),
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
