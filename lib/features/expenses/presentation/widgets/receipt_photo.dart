import 'dart:io';

import 'package:flutter/material.dart';

/// A stored receipt image, decoded at the width it is shown rather than the
/// camera's (a 12 MP photo is about 48 MB decoded), and announced as
/// "Receipt photo".
class ReceiptPhoto extends StatelessWidget {
  final String path;
  final double? height;
  final ImageErrorWidgetBuilder errorBuilder;

  const ReceiptPhoto({
    super.key,
    required this.path,
    required this.errorBuilder,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Image.file(
        File(path),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: constraints.hasBoundedWidth
            ? (constraints.maxWidth * pixelRatio).round()
            : null,
        semanticLabel: 'Receipt photo',
        errorBuilder: errorBuilder,
      ),
    );
  }
}
