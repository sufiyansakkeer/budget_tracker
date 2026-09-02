import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/di/injection.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../bloc/budget_bloc.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// A responsive, tappable selector that shows the active budget's name and
/// date range. Tapping it opens a bottom sheet to switch/create/open/edit
/// budgets. Dispatches [BudgetRefreshBus] so the whole app refreshes.
class ActiveBudgetSelector extends StatefulWidget {
  const ActiveBudgetSelector({super.key});

  @override
  State<ActiveBudgetSelector> createState() => _ActiveBudgetSelectorState();
}

class _ActiveBudgetSelectorState extends State<ActiveBudgetSelector> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  BudgetEntity? _active;

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  Future<void> _loadActive() async {
    final active = await _manageBudget.getActive();
    if (!mounted) return;
    setState(() => _active = active);
  }

  Future<void> _showSelector() async {
    final budgets = await _manageBudget.getAll();
    final activeId = await _manageBudget.activeBudgetId();
    if (!mounted) return;

    final action = await showModalBottomSheet<BudgetAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Your Budgets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...budgets.map((budget) {
                        final isActive = budget.id == activeId;
                        return ListTile(
                          leading: Icon(
                            isActive
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isActive
                                ? context.appColors.secondary
                                : null,
                          ),
                          title: Text(budget.name),
                          subtitle: Text(
                            '${_fmt(budget.startDate)} → ${_fmt(budget.endDate)}'
                            '${budget.isArchived ? '  •  Archived' : ''}',
                          ),
                          enabled: !budget.isArchived || isActive,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(BudgetAction.select(budget)),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, size: 20),
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(BudgetAction.open(budget)),
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.add),
                        title: Text('Create New Budget'),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(const BudgetAction.create()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    switch (action.type) {
      case BudgetActionType.create:
        await context.push('/app/budgets/create');
        await _loadActive();
        BudgetRefreshBus.instance.notifyChanged();
      case BudgetActionType.open:
        await context.push('/app/budgets/${action.budget!.id}');
      case BudgetActionType.select:
        final budget = action.budget!;
        if (budget.isArchived) return;
        await _manageBudget.setActive(budget.id);
        if (!mounted) return;
        setState(() => _active = budget);
        BudgetRefreshBus.instance.notifyChanged();
    }
  }

  String _fmt(DateTime d) => DateFormat('d MMM').format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = _active;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showSelector,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: context.appColors.secondary,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget?.name ?? 'No Budget',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (budget != null)
                      Text(
                        '${_fmt(budget.startDate)} → ${_fmt(budget.endDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

enum BudgetActionType { select, open, create }

class BudgetAction {
  final BudgetActionType type;
  final BudgetEntity? budget;

  const BudgetAction(this.type, this.budget);

  factory BudgetAction.select(BudgetEntity b) =>
      BudgetAction(BudgetActionType.select, b);
  factory BudgetAction.open(BudgetEntity b) =>
      BudgetAction(BudgetActionType.open, b);
  const BudgetAction.create() : this(BudgetActionType.create, null);
}
