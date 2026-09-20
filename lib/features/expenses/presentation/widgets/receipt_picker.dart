import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/services/receipt_storage_service.dart';

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
    if (oldWidget.receiptPath != widget.receiptPath) _checkFile();
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
    final path = switch (option) {
      ImageSourceOption.camera => await service.captureReceipt(),
      ImageSourceOption.gallery => await service.pickReceiptFromGallery(),
    };
    if (path != null) widget.onChanged(path);
  }

  Future<void> _showPicker() async {
    final option = await AppBottomSheet.show<ImageSourceOption>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(title: 'Attach a receipt'),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSourceOption.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSourceOption.gallery),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
    if (option != null) await _pick(option);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReceipt = widget.receiptPath != null && _exists;

    final Widget content;
    if (_checking) {
      content = const SizedBox(
        key: ValueKey('checking'),
        height: AppSizes.touchTarget,
        child: Center(
          child: SizedBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (hasReceipt) {
      content = _buildPreview(theme, key: const ValueKey('preview'));
    } else if (widget.receiptPath != null) {
      content = _buildMissing(theme, key: const ValueKey('missing'));
    } else {
      content = _buildEmpty(theme, key: const ValueKey('empty'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
          child: content,
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme, {Key? key}) {
    return AppCard(
      key: key,
      onTap: _showPicker,
      color: theme.colorScheme.surfaceContainer,
      showBorder: false,
      borderRadius: AppSpacing.borderRadiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        key: const Key('receiptPicker'),
        children: [
          IconTile(
            icon: Icons.receipt_long_rounded,
            color: theme.colorScheme.primary,
            size: AppSizes.avatarSm,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap to attach a receipt',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  'Photo or image from your gallery',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.add_a_photo_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppSpacing.borderRadiusMd,
          child: Image.file(
            File(widget.receiptPath!),
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildMissing(theme),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _showPicker,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Replace'),
            ),
            TextButton.icon(
              onPressed: () => widget.onChanged(null),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMissing(ThemeData theme, {Key? key}) {
    return AppCard(
      key: key,
      color: theme.colorScheme.errorContainer,
      showBorder: false,
      borderRadius: AppSpacing.borderRadiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Text(
              'Receipt file is missing',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: _showPicker,
            child: const Text('Choose another'),
          ),
        ],
      ),
    );
  }
}

enum ImageSourceOption { camera, gallery }
