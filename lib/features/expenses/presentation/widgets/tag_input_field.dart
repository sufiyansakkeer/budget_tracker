import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/validators/expense_validator.dart';

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
        _error = 'Cannot add more than ${ExpenseValidator.maxTags} tags';
      });
      return;
    }

    if (_tags.contains(text)) {
      setState(() {
        _error = 'Tag "$text" already added';
      });
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Tags (optional)',
            hintText: 'e.g. Office, Family, Business',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline),
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
            runSpacing: AppSpacing.sm,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
