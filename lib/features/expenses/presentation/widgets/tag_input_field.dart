import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../domain/validators/expense_validator.dart';
import '../../../../core/theme/contrast.dart';

/// Allows adding/removing multiple tags as chips.
class TagInputField extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagInputField({
    super.key,
    this.initialTags = const [],
    required this.onTagsChanged,
  });

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  late final List<String> _tags = List.of(widget.initialTags);
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_tags.length >= ExpenseValidator.maxTags) {
      setState(() {
        _error = 'You can add up to ${ExpenseValidator.maxTags} tags';
      });
      return;
    }
    if (_tags.contains(text)) {
      setState(() => _error = '"$text" is already added');
      return;
    }

    setState(() {
      _tags.add(text);
      _controller.clear();
      _error = null;
    });
    widget.onTagsChanged(List.unmodifiable(_tags));
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
            labelText: 'Tags',
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
