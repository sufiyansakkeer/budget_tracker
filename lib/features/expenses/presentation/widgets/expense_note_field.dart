import 'package:flutter/material.dart';

import '../../domain/validators/expense_validator.dart';

/// Multiline note field with a character counter capped at 500.
class ExpenseNoteField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const ExpenseNoteField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      minLines: 2,
      maxLength: ExpenseValidator.maxNoteLength,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: 'Note',
        hintText: 'What was this for?',
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: Icon(Icons.notes_rounded),
        ),
        errorText: errorText,
      ),
      onChanged: onChanged,
      validator: (_) => errorText,
    );
  }
}
