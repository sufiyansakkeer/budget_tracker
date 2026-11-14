import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../domain/validators/expense_validator.dart';
import '../../../../core/theme/contrast.dart';

/// Allows adding/removing multiple tags as chips. A tag is added with +
/// or the keyboard's Done; a form that saves calls
/// [TagInputFieldState.commitPending] so a tag still being typed is kept.
class TagInputField extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagInputField({
    super.key,
    this.initialTags = const [],
    required this.onTagsChanged,
  });

  @override
  State<TagInputField> createState() => TagInputFieldState();
}

class TagInputFieldState extends State<TagInputField> {
  late final List<String> _tags = List.of(widget.initialTags);
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Adds the text still in the field as a tag, as + would. Returns why
  /// it couldn't be added (it is then shown on the field), or null. Text
  /// that is already a tag is simply cleared: nothing is lost.
  String? commitPending() {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    if (_tags.contains(text)) {
      setState(() {
        _controller.clear();
        _error = null;
      });
      return null;
    }
    return _addTag();
  }

  String? _addTag() {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;

    if (_tags.length >= ExpenseValidator.maxTags) {
      final error = 'You can add up to ${ExpenseValidator.maxTags} tags';
      setState(() => _error = error);
      return error;
    }
    if (_tags.contains(text)) {
      final error = '"$text" is already added';
      setState(() => _error = error);
      return error;
    }

    setState(() {
      _tags.add(text);
      _controller.clear();
      _error = null;
    });
    widget.onTagsChanged(List.unmodifiable(_tags));
    return null;
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _error = null;
    });
    widget.onTagsChanged(List.unmodifiable(_tags));
  }

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Tags (optional)',
            hintText: 'e.g. Office, Family',
            prefixIcon: const Icon(Icons.sell_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _addTag,
              tooltip: 'Add tag',
            ),
            errorText: _error,
          ),
          onFieldSubmitted: (_) => _addTag(),
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: _tags.map((tag) {
              return InputChip(
                label: Text('#$tag'),
                onDeleted: () => _removeTag(tag),
                deleteButtonTooltipMessage: 'Remove $tag',
                backgroundColor: color.withValues(alpha: 0.1),
                side: BorderSide(color: color.withValues(alpha: 0.35)),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Contrast.ensureContrast(
                    color,
                    Color.alphaBlend(
                      color.withValues(alpha: 0.1),
                      Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
