import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import 'budget_details_screen.dart';

/// The Budget tab: the active budget's whole period
/// ([BudgetDetailsScreen.asTab]), following the active budget as it
/// changes. With no budget, an invitation to create one.
class BudgetTabScreen extends StatefulWidget {
  const BudgetTabScreen({super.key});

  @override
  State<BudgetTabScreen> createState() => _BudgetTabScreenState();
}

class _BudgetTabScreenState extends State<BudgetTabScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  StreamSubscription<void>? _budgetSubscription;
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _budgetSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _budgetSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    String? id;
    try {
      id = await _manageBudget.activeBudgetId();
    } catch (e) {
      debugPrint('[error] Reading the active budget: $e');
    }
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = _activeId;
    if (_loading) {
      return const Scaffold(
        body: FormSkeleton(key: ValueKey('loading'), rows: 4),
      );
    }
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget')),
        body: EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Create your first budget',
          message:
              'A budget gives you a daily safe-spending amount and keeps '
              'every expense in context.',
          actionLabel: 'Create budget',
          actionIcon: Icons.add_rounded,
          onAction: () => context.pushUnique('/app/budgets/create'),
        ),
      );
    }
    // Keyed by budget, so a switch builds the new budget's screen.
    return AppStateSwitcher(
      child: BudgetDetailsScreen(
        key: ValueKey('budget_tab_$id'),
        budgetId: id,
        asTab: true,
      ),
    );
  }
}
