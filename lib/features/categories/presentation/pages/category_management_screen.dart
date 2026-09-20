import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/category_state.dart';
import '../widgets/category_form_sheet.dart';

/// Manage expense categories: create, rename, restyle, archive, delete.
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  static const _info = InfoContent(
    title: 'Categories',
    whatIsThis:
        'Labels for your expenses. Every expense belongs to exactly one '
        'category, which drives the category breakdown in Reports and the '
        'quick filters in Expenses.',
    howIsItCalculated:
        'Built-in categories come with the app and can be renamed and '
        'restyled but not deleted. Categories you add can be deleted while '
        'no expense uses them.',
    additionalNotes:
        '• Archiving hides a category from the expense form and quick '
        'filters. Existing expenses keep it and still appear in reports\n'
        '• Restore an archived category at any time\n'
        '• At least one category always stays available',
  );

  @override
  void initState() {
    super.initState();
    context.read<CategoryBloc>().add(const CategoryLoad());
  }

  Future<void> _openForm(
    BuildContext context, {
    ExpenseCategory? category,
  }) async {
    final bloc = context.read<CategoryBloc>();
    final draft = await CategoryFormSheet.show(
      context,
      category: category,
      existing: bloc.state.categories,
    );
    if (draft == null) return;
    bloc.add(
      CategorySave(
        id: draft.id,
        name: draft.name,
        icon: draft.icon,
        colorHex: draft.colorHex,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseCategory category,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete category?',
      message:
          '"${category.name}" will be removed. This only works while no '
          'expense uses it.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<CategoryBloc>().add(CategoryDelete(category.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [InfoIcon(content: _info)],
      ),
      floatingActionButton: AppFab(
        heroTag: 'categories_fab',
        onPressed: () => _openForm(context),
        icon: Icons.add_rounded,
        label: 'New category',
      ),
      body: BlocConsumer<CategoryBloc, CategoryState>(
        listenWhen: (prev, curr) =>
            curr.message != null && curr.message != prev.message ||
            curr.errorMessage != null && curr.errorMessage != prev.errorMessage,
        listener: (context, state) {
          final text = state.message ?? state.errorMessage;
          if (text == null) return;
          final isError = state.message == null;
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(text),
                backgroundColor: isError ? scheme.errorContainer : null,
                showCloseIcon: isError,
              ),
            );
          context.read<CategoryBloc>().add(const CategoryClearMessage());
        },
        builder: (context, state) {
          final Widget child;
          if (state.status == CategoryBlocStatus.loading ||
              state.status == CategoryBlocStatus.initial) {
            child = const Padding(
              key: ValueKey('loading'),
              padding: AppSpacing.pagePadding,
              child: Shimmer(
                child: Column(
                  children: [
                    SkeletonListTile(),
                    SkeletonListTile(),
                    SkeletonListTile(),
                    SkeletonListTile(),
                  ],
                ),
              ),
            );
          } else if (state.status == CategoryBlocStatus.error &&
              state.categories.isEmpty) {
            child = ErrorState(
              key: const ValueKey('error'),
              message: state.errorMessage ?? 'Categories could not be loaded',
              onRetry: () =>
                  context.read<CategoryBloc>().add(const CategoryLoad()),
            );
          } else if (state.categories.isEmpty) {
            child = EmptyState(
              key: const ValueKey('empty'),
              icon: Icons.category_outlined,
              title: 'No categories yet',
              message: 'Add a category to start labelling expenses.',
              actionLabel: 'New category',
              actionIcon: Icons.add_rounded,
              onAction: () => _openForm(context),
            );
          } else {
            child = _CategoryList(
              key: const ValueKey('loaded'),
              state: state,
              onEdit: (c) => _openForm(context, category: c),
              onArchive: (c, archived) => context.read<CategoryBloc>().add(
                CategorySetArchived(c.id, archived: archived),
              ),
              onDelete: (c) => _confirmDelete(context, c),
            );
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final CategoryState state;
  final ValueChanged<ExpenseCategory> onEdit;
  final void Function(ExpenseCategory category, bool archived) onArchive;
  final ValueChanged<ExpenseCategory> onDelete;

  const _CategoryList({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = state.active;
    final archived = state.archived;
    var index = 0;
    return ListView(
      padding: AppSpacing.pagePaddingWithFab,
      children: [
        SectionHeader(
          title: 'Available',
          subtitle:
              '${active.length} ${active.length == 1 ? 'category' : 'categories'}',
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final c in active)
          FadeSlideIn(
            key: ValueKey('enter_${c.id}'),
            index: index++,
            child: CategoryListTile(
              category: c,
              onTap: () => onEdit(c),
              onArchive: () => onArchive(c, true),
              onDelete: c.isSystem ? null : () => onDelete(c),
            ),
          ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Archived',
            subtitle: 'Hidden from the expense form; history is kept',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in archived)
            FadeSlideIn(
              key: ValueKey('enter_${c.id}'),
              index: index++,
              child: CategoryListTile(
                category: c,
                onTap: () => onEdit(c),
                onRestore: () => onArchive(c, false),
                onDelete: c.isSystem ? null : () => onDelete(c),
              ),
            ),
        ],
      ],
    );
  }
}

/// One category row with its actions in an overflow menu.
class CategoryListTile extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const CategoryListTile({
    super.key,
    required this.category,
    required this.onTap,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryVisuals.adaptiveColor(context, category.colorHex);
    final subtitle = [
      category.isSystem ? 'Built-in' : 'Custom',
      if (category.isArchived) 'Archived',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        key: Key('category_row_${category.id}'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Opacity(
              opacity: category.isArchived ? 0.55 : 1,
              child: IconTile(
                icon: CategoryVisuals.iconFor(category.icon),
                color: color,
                size: AppSizes.avatarMd,
                animate: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_CategoryAction>(
              key: Key('category_menu_${category.id}'),
              tooltip: 'More options',
              onSelected: (action) {
                switch (action) {
                  case _CategoryAction.edit:
                    onTap();
                  case _CategoryAction.archive:
                    onArchive?.call();
                  case _CategoryAction.restore:
                    onRestore?.call();
                  case _CategoryAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _CategoryAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                if (onArchive != null)
                  const PopupMenuItem(
                    value: _CategoryAction.archive,
                    child: ListTile(
                      leading: Icon(Icons.archive_outlined),
                      title: Text('Archive'),
                    ),
                  ),
                if (onRestore != null)
                  const PopupMenuItem(
                    value: _CategoryAction.restore,
                    child: ListTile(
                      leading: Icon(Icons.unarchive_outlined),
                      title: Text('Restore'),
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _CategoryAction.delete,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CategoryAction { edit, archive, restore, delete }
