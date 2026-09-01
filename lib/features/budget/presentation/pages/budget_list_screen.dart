import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/entities/budget_list_summary_entity.dart';
import '../../domain/usecases/get_budget_list_summary_usecase.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../bloc/budget_bloc.dart';
import '../widgets/budget_card.dart';
import '../widgets/budget_list_summary_card.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Lists all budgets and allows opening/editing/archiving/deleting them.
class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  late final GetBudgetListSummaryUseCase _getSummaryUseCase =
      getIt<GetBudgetListSummaryUseCase>();
  List<BudgetEntity>? _budgets;
  BudgetListSummaryEntity? _summary;
  String? _activeBudgetId;
  bool _loading = true;
  String? _error;
  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  @override
  void initState() {
    super.initState();
    _load();

    // Auto-refresh when expenses change
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!mounted) return;
      _load();
    });

    // Auto-refresh when budgets change
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final budgets = await _manageBudget.getAll();
      final activeId = await _manageBudget.activeBudgetId();
      final summaryResult = await _getSummaryUseCase();

      if (!mounted) return;

      BudgetListSummaryEntity? summary;
      if (summaryResult case BudgetSuccess(:final data)) {
        summary = data;
      }

      setState(() {
        _budgets = budgets;
        _activeBudgetId = activeId;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load budgets.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            tooltip: 'New budget',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/app/budgets/create'),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/budgets/create'),
        backgroundColor: context.appColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
        tooltip: 'Create a new budget',
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final budgets = _budgets ?? const <BudgetEntity>[];
    if (budgets.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_rounded,
        title: 'No budgets yet',
        message: 'Create your first budget to start tracking your spending.',
        actionLabel: 'Create Budget',
        actionIcon: Icons.add_rounded,
        onAction: () => context.push('/app/budgets/create'),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_summary != null && _summary!.activeBudgetCount > 0) ...[
            BudgetListSummaryCard(summary: _summary!),
            const SizedBox(height: AppSpacing.md),
          ],
          ...budgets.map(
            (budget) => BudgetCard(
              budget: budget,
              isActive: budget.id == _activeBudgetId,
              onTap: () => context.push('/app/budgets/${budget.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
