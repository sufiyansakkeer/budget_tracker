import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/di/injection.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../bloc/budget_bloc.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// A reusable dropdown that lets the user switch the active budget.
///
/// Shows the active budget name and opens a bottom-sheet selector listing all
/// budgets. Selecting one dispatches [BudgetSwitchEvent] and refreshes the app.
class BudgetSwitcher extends StatefulWidget {
  const BudgetSwitcher({super.key});

  @override
  State<BudgetSwitcher> createState() => _BudgetSwitcherState();
}

class _BudgetSwitcherState extends State<BudgetSwitcher> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  String? _activeName;

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  Future<void> _loadActive() async {
    final active = await _manageBudget.getActive();
    if (!mounted) return;
    setState(() => _activeName = active?.name);
  }

  Future<void> _showSelector() async {
    final budgets = await _manageBudget.getAll();
    final activeId = await _manageBudget.activeBudgetId();
    if (!mounted) return;

    final selected = await showModalBottomSheet<BudgetEntity>(
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Switch Budget',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add budget',
                        icon: const Icon(Icons.add),
                        onPressed: () => context.push('/app/budgets/create'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: budgets.map((budget) {
                      final isActive = budget.id == activeId;
                      return ListTile(
                        leading: Icon(
                          isActive ? Icons.check_circle : Icons.circle_outlined,
                          color: isActive ? context.appColors.secondary : null,
                        ),
                        title: Text(budget.name),
                        subtitle: Text(
                          isActive
                              ? 'Active budget'
                              : budget.isArchived
                              ? 'Archived'
                              : '',
                        ),
                        enabled: !budget.isArchived,
                        onTap: () => Navigator.of(context).pop(budget),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    if (selected.isArchived) return;

    await _manageBudget.setActive(selected.id);
    if (!mounted) return;
    setState(() => _activeName = selected.name);

    // Notify the broader app (dashboard, reports, expenses) to refresh.
    BudgetRefreshBus.instance.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _showSelector,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet, size: 18),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                _activeName ?? 'Budget',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
