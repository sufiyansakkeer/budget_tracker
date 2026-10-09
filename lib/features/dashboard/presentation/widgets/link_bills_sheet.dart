import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_failure.dart';
import '../../../bills/domain/usecases/link_bills_to_budget_usecase.dart';
import '../../../budget/domain/entities/budget_error.dart';
import '../../domain/usecases/get_linkable_bills_usecase.dart';
import 'safe_to_spend_copy.dart';
import '../../../../core/errors/user_facing_error.dart';
import '../../../bills/presentation/bill_failure_copy.dart';

/// "Link bills": links upcoming bills that no budget sets aside to the
/// active budget, so Today's Safe Spending keeps money for them.
///
/// Lists exactly the bills the dashboard's "Bills not linked" notice counts
/// ([GetLinkableBillsUseCase]); bills in another currency are shown but
/// cannot be selected. Linking runs in one transaction
/// ([LinkBillsToBudgetUseCase]) and notifies [RefreshBuses.bills], so the
/// dashboard recalculates.
abstract final class LinkBillsSheet {
  static Future<void> open(
    BuildContext context, {
    required String budgetId,
  }) async {
    final LinkableBills bills;
    try {
      final result = await getIt<GetLinkableBillsUseCase>()(budgetId: budgetId);
      switch (result) {
        case BudgetError(:final failure):
          if (context.mounted) {
            _snack(
              context,
              userFacingError(
                failure.message,
                forPeople: false,
                fallback: "Couldn't load this budget. Try again.",
              ),
            );
          }
          return;
        case BudgetSuccess(:final data):
          bills = data;
      }
    } catch (_) {
      if (context.mounted) _snack(context, "Couldn't load your bills.");
      return;
    }
    if (!context.mounted) return;
    if (bills.linkable.isEmpty && bills.otherCurrency.isEmpty) {
      _snack(context, 'Every upcoming bill is already set aside.');
      return;
    }

    final selected = await AppBottomSheet.show<List<String>>(
      context: context,
      builder: (_) => LinkBillsSheetContent(bills: bills),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;

    final result = await getIt<LinkBillsToBudgetUseCase>()(
      budgetId: budgetId,
      billIds: selected,
    );
    if (!context.mounted) return;
    switch (result) {
      case BillSuccess(:final data):
        RefreshBuses.bills.notifyChanged();
        _snack(
          context,
          'Linked ${data.length} ${data.length == 1 ? 'bill' : 'bills'} to '
          '${bills.budget.name}.',
        );
      case BillError(:final failure):
        _snack(context, failure.shown("Couldn't link the bills. Try again."));
    }
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

/// The sheet's content. Pops the selected bill ids (all linkable bills are
/// selected to start with).
class LinkBillsSheetContent extends StatefulWidget {
  final LinkableBills bills;

  const LinkBillsSheetContent({super.key, required this.bills});

  @override
  State<LinkBillsSheetContent> createState() => _LinkBillsSheetContentState();
}

class _LinkBillsSheetContentState extends State<LinkBillsSheetContent> {
  late final Set<String> _selected = {
    for (final bill in widget.bills.linkable) bill.id,
  };

  String _due(BillEntity bill) =>
      'Due ${SafeToSpendCopy.date(bill.dueDate)} · '
      '${SafeToSpendCopy.amount(bill.amount, bill.currency)}';

  @override
  Widget build(BuildContext context) {
    final budget = widget.bills.budget;
    final count = _selected.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: 'Link bills to ${budget.name}',
          subtitle:
              "Linked bills are set aside from this budget until they're "
              'paid.',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final bill in widget.bills.linkable)
                CheckboxListTile(
                  key: ValueKey('link_${bill.id}'),
                  value: _selected.contains(bill.id),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selected.add(bill.id);
                    } else {
                      _selected.remove(bill.id);
                    }
                  }),
                  title: Text(bill.title),
                  subtitle: Text(_due(bill)),
                ),
              for (final bill in widget.bills.otherCurrency)
                CheckboxListTile(
                  key: ValueKey('link_${bill.id}'),
                  value: false,
                  onChanged: null,
                  title: Text(bill.title),
                  subtitle: Text(
                    'In ${bill.currency} · this budget uses '
                    '${budget.currency}',
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: FilledButton(
            onPressed: count == 0
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
            child: Text(
              count == 0
                  ? 'Select bills to link'
                  : 'Link $count ${count == 1 ? 'bill' : 'bills'}',
            ),
          ),
        ),
      ],
    );
  }
}
