import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_visuals.dart';
import '../widgets/delete_expense_dialog.dart';

/// Dedicated detail page for a single expense.
class ExpenseDetailsScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailsScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(ExpenseLoadById(widget.expenseId));
    if (context.read<ExpenseBloc>().state.categories.isEmpty) {
      context.read<ExpenseBloc>().add(const ExpenseLoadCategories());
    }
  }

  Future<void> _confirmDelete(ExpenseEntity expense, String currency) async {
    final confirmed = await showDeleteExpenseDialog(
      context,
      amount: expense.amount,
      currency: currency,
    );
    if (confirmed) {
      if (mounted) {
        context.read<ExpenseBloc>().add(ExpenseDelete(expense.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              final expense = state.expense;
              if (expense == null) return const SizedBox.shrink();
              return IconButton(
                key: const Key('editExpenseButton'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit expense',
                onPressed: () => context.push('/expenses/edit/${expense.id}'),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.status == ExpenseBlocStatus.success &&
              state.message?.contains('deleted') == true) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Expense deleted')));
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
            context.pop();
          } else if (state.status == ExpenseBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                  backgroundColor: AppColors.dangerRed,
                ),
              );
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
          }
        },
        builder: (context, state) {
          if (state.status == ExpenseBlocStatus.loading &&
              state.expense == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final expense = state.expense;
          if (expense == null) {
            return const Center(child: Text('Expense not found'));
          }

          final category = _findCategory(state.categories, expense.categoryId);
          return _buildDetails(expense, category);
        },
      ),
    );
  }

  ExpenseCategory? _findCategory(List<ExpenseCategory> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Widget _buildDetails(ExpenseEntity expense, ExpenseCategory? category) {
    final theme = Theme.of(context);
    final icon = category != null
        ? CategoryVisuals.iconFor(category.icon)
        : Icons.help_outline;
    final categoryName = category?.name ?? 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  categoryName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 2,
                  ).format(expense.amount),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Info card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _infoRow(
                    theme,
                    Icons.calendar_today_outlined,
                    'Date',
                    DateFormat('EEE, MMM d, yyyy').format(expense.date),
                  ),
                  _infoRow(
                    theme,
                    Icons.access_time,
                    'Time',
                    DateFormat('h:mm a').format(expense.time),
                  ),
                  _infoRow(
                    theme,
                    Icons.category_outlined,
                    'Category',
                    categoryName,
                  ),
                  if (expense.note != null && expense.note!.isNotEmpty)
                    _infoRow(theme, Icons.notes, 'Note', expense.note!),
                  if (expense.tags.isNotEmpty)
                    _infoRow(
                      theme,
                      Icons.sell_outlined,
                      'Tags',
                      expense.tags.join(', '),
                    ),
                  _infoRow(
                    theme,
                    Icons.add_circle_outline,
                    'Created',
                    DateFormat('MMM d, yyyy h:mm a').format(expense.createdAt),
                  ),
                  _infoRow(
                    theme,
                    Icons.update,
                    'Updated',
                    DateFormat('MMM d, yyyy h:mm a').format(expense.updatedAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Receipt
          if (expense.receiptImagePath != null) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (File(expense.receiptImagePath!).existsSync())
                      ClipRRect(
                        borderRadius: AppSpacing.borderRadiusMd,
                        child: Image.file(
                          File(expense.receiptImagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const Text('Receipt unavailable'),
                        ),
                      )
                    else
                      Text(
                        'Receipt file is missing',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Delete button
          OutlinedButton.icon(
            key: const Key('deleteExpenseButton'),
            onPressed: () => _confirmDelete(expense, '₹'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerRed,
              side: const BorderSide(color: AppColors.dangerRed),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Expense'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
