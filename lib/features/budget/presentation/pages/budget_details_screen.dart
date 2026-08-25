import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../bloc/budget_bloc.dart';

/// Entry point for a selected budget: shows info, statistics, period, status
/// and quick actions (edit, archive, duplicate, delete, set active, add expense).
class BudgetDetailsScreen extends StatefulWidget {
  final String budgetId;

  const BudgetDetailsScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  late final BudgetRepository _budgetRepository = getIt<BudgetRepository>();

  BudgetEntity? _budget;
  MonthlyStatisticsEntity _stats = MonthlyStatisticsEntity.empty;
  bool _isActive = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final activeId = await _manageBudget.activeBudgetId();
    final budget = await _manageBudget.getById(widget.budgetId);
    final stats = budget == null
        ? MonthlyStatisticsEntity.empty
        : await _budgetRepository.getBudgetStatistics(
            budget.id,
            referenceDate: DateTime.now(),
          );
    if (!mounted) return;
    setState(() {
      _budget = budget;
      _stats = stats;
      _isActive = budget?.id == activeId;
      _loading = false;
    });
  }

  Future<void> _setActive() async {
    await _manageBudget.setActive(widget.budgetId);
    BudgetRefreshBus.instance.notifyChanged();
    if (!mounted) return;
    setState(() => _isActive = true);
  }

  Future<void> _archive() async {
    setState(() => _busy = true);
    await _manageBudget.archive(widget.budgetId, archived: true);
    BudgetRefreshBus.instance.notifyChanged();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _budget = _budget?.copyWith(isArchived: true);
    });
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await _manageBudget.archive(widget.budgetId, archived: false);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _budget = _budget?.copyWith(isArchived: false);
    });
  }

  Future<void> _duplicate() async {
    final nameController = TextEditingController(
      text: '${_budget!.name} (Copy)',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Budget'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New budget name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await _manageBudget.duplicate(
      widget.budgetId,
      newName: nameController.text.trim(),
    );
    nameController.dispose();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Budget duplicated')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text(
          'This will permanently delete the budget and ALL its expenses. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _manageBudget.delete(widget.budgetId);
    BudgetRefreshBus.instance.notifyChanged();
    if (!mounted) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = getIt<CurrencyProvider>().currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Details'),
        actions: [
          if (_budget != null)
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    context.push('/app/budgets/${widget.budgetId}/edit');
                  case 'setActive':
                    _setActive();
                  case 'archive':
                    _archive();
                  case 'restore':
                    _restore();
                  case 'duplicate':
                    _duplicate();
                  case 'delete':
                    _delete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!_isActive)
                  const PopupMenuItem(
                    value: 'setActive',
                    child: Text('Set Active'),
                  ),
                if (_budget?.isArchived == false)
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                if (_budget?.isArchived == true)
                  const PopupMenuItem(value: 'restore', child: Text('Restore')),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicate'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _budget == null
            ? const Center(child: Text('Budget not found'))
            : _buildContent(theme, currency),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, String currency) {
    final budget = _budget!;
    final today = DateTime.now();
    final remaining = budget.daysRemaining(today);
    final spent = _stats.totalSpent;
    final utilization = budget.monthlyAmount <= 0
        ? 0.0
        : spent / budget.monthlyAmount;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildHeaderCard(theme, budget, currency),
        const SizedBox(height: AppSpacing.md),
        if (!_isActive || budget.isArchived) _buildActiveBanner(theme, budget),
        const SizedBox(height: AppSpacing.md),
        _buildStatGrid(theme, currency, budget, spent, utilization, remaining),
        const SizedBox(height: AppSpacing.md),
        _buildProgressCard(theme, budget, utilization),
        const SizedBox(height: AppSpacing.md),
        _buildQuickActions(theme, currency, remaining),
      ],
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    BudgetEntity budget,
    String currency,
  ) {
    String fmt(DateTime d) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    budget.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(archived: budget.isArchived, active: _isActive),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${fmt(budget.startDate)} → ${fmt(budget.endDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$currency${budget.monthlyAmount.toStringAsFixed(0)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (budget.notes != null && budget.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(budget.notes!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBanner(ThemeData theme, BudgetEntity budget) {
    final message = budget.isArchived
        ? 'This budget is archived and read-only.'
        : 'This is not the active budget.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            budget.isArchived ? Icons.archive : Icons.info_outline,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
          if (!budget.isArchived)
            TextButton(onPressed: _setActive, child: const Text('Make Active')),
        ],
      ),
    );
  }

  Widget _buildStatGrid(
    ThemeData theme,
    String currency,
    BudgetEntity budget,
    double spent,
    double utilization,
    int remaining,
  ) {
    final remainingBudget = budget.monthlyAmount - spent;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.payments,
            label: 'Spent',
            value: '$currency${spent.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.savings,
            label: 'Remaining',
            value: '$currency${remainingBudget.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.av_timer,
            label: 'Days Left',
            value: '$remaining',
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    ThemeData theme,
    BudgetEntity budget,
    double utilization,
  ) {
    final percent = (utilization * 100).clamp(0, 100).toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budget Used', style: theme.textTheme.titleMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InfoIcon(
                      content: InfoContent(
                        title: 'Budget Progress',
                        whatIsThis:
                            'Shows how much of this budget has been used '
                            'and how much remains.',
                        howIsItCalculated:
                            'Progress = Spent ÷ Budget amount × 100\n'
                            'Remaining = Budget amount − Spent amount',
                        example:
                            'Budget: ₹30,000\n'
                            'Spent: ₹18,000\n'
                            'Progress: 18,000 ÷ 30,000 = 60%\n'
                            'Remaining: ₹12,000',
                        additionalNotes:
                            '• Start date and end date define the period\n'
                            '• Flexible date ranges: budget can start and '
                              'end on any dates\n'
                            '• Color changes: green (< 80%), orange (80–100%), '
                              'red (> 100%)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: utilization,
                minHeight: 10,
                backgroundColor: theme.disabledColor.withValues(alpha: 0.2),
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, String currency, int remaining) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (!_budget!.isArchived)
                  _ActionButton(
                    icon: Icons.add,
                    label: 'Add Expense',
                    onPressed: () => context.push('/app/expenses/add'),
                  ),
                _ActionButton(
                  icon: Icons.history,
                  label: 'View Expenses',
                  onPressed: () => context.push('/app/expenses'),
                ),
                _ActionButton(
                  icon: Icons.bar_chart,
                  label: 'Reports',
                  onPressed: () => context.push('/app/reports'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool archived;
  final bool active;

  const _StatusChip({required this.archived, required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = archived ? 'Archived' : (active ? 'Active' : 'Inactive');
    final color = archived
        ? theme.disabledColor
        : (active ? AppColors.primary : theme.hintColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
