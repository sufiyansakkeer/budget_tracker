import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/services/receipt_storage_service.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Receipt attachment widget supporting camera capture, gallery pick,
/// preview, replace, and remove.
class ReceiptPicker extends StatefulWidget {
  final String? receiptPath;
  final ValueChanged<String?> onChanged;

  const ReceiptPicker({
    super.key,
    required this.receiptPath,
    required this.onChanged,
  });

  @override
  State<ReceiptPicker> createState() => _ReceiptPickerState();
}

class _ReceiptPickerState extends State<ReceiptPicker> {
  bool _exists = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  @override
  void didUpdateWidget(covariant ReceiptPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptPath != widget.receiptPath) {
      _checkFile();
    }
  }

  void _checkFile() {
    final path = widget.receiptPath;
    setState(() {
      _exists =
          path != null && ReceiptStorageService.instance.receiptExists(path);
      _checking = false;
    });
  }

  Future<void> _pick(ImageSourceOption option) async {
    final service = ReceiptStorageService.instance;
    String? path;
    switch (option) {
      case ImageSourceOption.camera:
        path = await service.captureReceipt();
      case ImageSourceOption.gallery:
        path = await service.pickReceiptFromGallery();
    }
    if (path != null) {
      widget.onChanged(path);
    }
  }

  void _remove() {
    widget.onChanged(null);
  }

  Future<void> _showPicker() async {
    final option = await showModalBottomSheet<ImageSourceOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Capture from camera'),
              onTap: () => Navigator.pop(context, ImageSourceOption.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.pop(context, ImageSourceOption.gallery),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (option != null) {
      await _pick(option);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReceipt = widget.receiptPath != null && _exists;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt (optional)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_checking)
            const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (hasReceipt)
            _buildReceiptPreview(theme)
          else if (widget.receiptPath != null)
            _buildMissingFile(theme)
          else
            _buildEmpty(theme),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return InkWell(
      key: const Key('receiptPicker'),
      onTap: _showPicker,
      borderRadius: AppSpacing.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.surfaceContainerHighest,
            width: 1.5,
          ),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, color: context.appColors.secondary, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text('Tap to attach a receipt', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPreview(ThemeData theme) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusMd,
          child: Image.file(
            File(widget.receiptPath!),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildMissingFile(theme),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _showPicker,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Replace'),
            ),
            TextButton.icon(
              onPressed: _remove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMissingFile(ThemeData theme) {
    return Column(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Receipt file is missing',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: _showPicker,
          icon: const Icon(Icons.refresh),
          label: const Text('Choose another'),
        ),
      ],
    );
  }
}

enum ImageSourceOption { camera, gallery }
