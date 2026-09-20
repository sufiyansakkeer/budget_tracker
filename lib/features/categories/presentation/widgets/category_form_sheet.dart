import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/category_catalog.dart';
import '../../domain/validators/category_validator.dart';

/// What the user entered in [CategoryFormSheet].
class CategoryDraft {
  final String? id;
  final String name;
  final String icon;
  final String colorHex;

  const CategoryDraft({
    this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
  });
}

/// Bottom sheet to create or edit a category: name, icon grid, colour
/// swatches and a live preview. Returns a [CategoryDraft] on save, null when
/// dismissed. Validation is inline; uniqueness is checked against
/// [existing] so the user sees the clash before saving.
class CategoryFormSheet extends StatefulWidget {
  final ExpenseCategory? category;
  final List<ExpenseCategory> existing;

  const CategoryFormSheet({super.key, this.category, required this.existing});

  static Future<CategoryDraft?> show(
    BuildContext context, {
    ExpenseCategory? category,
    required List<ExpenseCategory> existing,
  }) {
    return AppBottomSheet.show<CategoryDraft>(
      context: context,
      builder: (_) => CategoryFormSheet(category: category, existing: existing),
    );
  }

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late String _icon = widget.category?.icon ?? CategoryCatalog.iconNames.first;
  late String _color =
      widget.category?.colorHex.toUpperCase() ??
      CategoryCatalog.colorHexes.first;
  String? _nameError;

  bool get _isEdit => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text;
    var error = CategoryValidator.validateName(name);
    if (error == null) {
      final clash = widget.existing.any(
        (c) =>
            c.id != widget.category?.id &&
            CategoryValidator.sameName(c.name, name),
      );
      if (clash) error = 'A category with this name already exists';
    }
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      CategoryDraft(
        id: widget.category?.id,
        name: name.trim(),
        icon: _icon,
        colorHex: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewColor = CategoryVisuals.adaptiveColor(context, _color);
    final previewName = _name.text.trim().isEmpty
        ? 'New category'
        : _name.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(
            title: _isEdit ? 'Edit category' : 'New category',
            subtitle: _isEdit && widget.category!.isSystem
                ? 'Built-in category · can be renamed and restyled'
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview
                Center(
                  child: Semantics(
                    label: 'Preview: $previewName',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconTile(
                          icon: CategoryVisuals.iconFor(_icon),
                          color: previewColor,
                          size: AppSizes.avatarLg,
                          animate: true,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AnimatedDefaultTextStyle(
                          duration: AppMotion.respectReducedMotion(
                            context,
                            AppMotion.fast,
                          ),
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: previewColor,
                          ),
                          child: Text(previewName),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const Key('categoryNameField'),
                  controller: _name,
                  autofocus: !_isEdit,
                  textCapitalization: TextCapitalization.words,
                  maxLength: CategoryValidator.maxNameLength,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: _nameError,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _nameError = null),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Icon', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final name in CategoryCatalog.iconNames)
                      _IconChoice(
                        key: Key('categoryIcon_$name'),
                        icon: CategoryVisuals.iconFor(name),
                        color: previewColor,
                        selected: name == _icon,
                        semanticLabel: name.replaceAll('_', ' '),
                        onTap: () => setState(() => _icon = name),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Colour', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final hex in CategoryCatalog.colorHexes)
                      _ColorChoice(
                        key: Key('categoryColor_$hex'),
                        color: CategoryVisuals.adaptiveColor(context, hex),
                        name: CategoryCatalog.colorName(hex),
                        selected: hex == _color,
                        onTap: () => setState(() => _color = hex),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  key: const Key('saveCategoryButton'),
                  label: _isEdit ? 'Save changes' : 'Add category',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  const _IconChoice({
    super.key,
    required this.icon,
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standardCurve,
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            duration: duration,
            scale: selected ? 1.1 : 1,
            child: Icon(
              icon,
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoice({
    super.key,
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.respectReducedMotion(context, AppMotion.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name colour',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.standardCurve,
              width: selected ? 34 : 28,
              height: selected ? 34 : 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: duration,
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('check'),
                        size: AppSizes.iconSm,
                        color:
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
