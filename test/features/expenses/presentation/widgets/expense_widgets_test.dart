import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_picker.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_amount_field.dart';
import 'package:monivo/features/expenses/presentation/widgets/receipt_picker.dart';

void main() {
  group('CategoryPicker', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders categories as chips', (tester) async {
      await tester.pumpWidget(
        wrap(
          CategoryPicker(
            categories: defaultCategories.take(3).toList(),
            selectedCategoryId: null,
            onSelected: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category_food')), findsOneWidget);
      expect(find.byKey(const Key('category_grocery')), findsOneWidget);
      expect(find.byKey(const Key('category_fuel')), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('shows chip placeholders, not a spinner, while categories '
        'load', (tester) async {
      await tester.pumpWidget(
        wrap(
          CategoryPicker(
            categories: const [],
            selectedCategoryId: null,
            onSelected: (_) {},
          ),
        ),
      );

      // Changed on purpose in the redesign: skeleton chips replace the
      // spinner, and they are announced once.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.bySemanticsLabel('Loading categories'), findsOneWidget);
    });

    testWidgets('calls onSelected when a category chip is tapped', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          CategoryPicker(
            categories: [defaultCategories[0]],
            selectedCategoryId: null,
            onSelected: (id) => selected = id,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pump();

      expect(selected, 'food');
    });
  });

  group('ExpenseAmountField', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders currency prefix and amount hint', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          ExpenseAmountField(
            controller: controller,
            currencySymbol: '₹',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('displays provided error text', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          ExpenseAmountField(
            controller: controller,
            currencySymbol: '₹',
            errorText: 'Amount cannot be empty',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Amount cannot be empty'), findsOneWidget);
    });
  });

  group('ReceiptPicker', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders empty state with tap prompt', (tester) async {
      await tester.pumpWidget(
        wrap(ReceiptPicker(receiptPath: null, onChanged: (_) {})),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tap to attach a receipt'), findsOneWidget);
      expect(find.byKey(const Key('receiptPicker')), findsOneWidget);
    });

    testWidgets('renders missing file message when path has no file', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ReceiptPicker(
            receiptPath: '/nonexistent/receipt.jpg',
            onChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Receipt file is missing'), findsOneWidget);
    });

    // UX-064: a 12 MP photo was decoded at full size for a 180 dp preview,
    // and had no label.
    testWidgets('the preview is decoded at its display size, and labelled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final dir = Directory.systemTemp.createTempSync('receipt');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/r.jpg')..writeAsBytesSync([0, 1, 2]);

      await tester.pumpWidget(
        wrap(ReceiptPicker(receiptPath: file.path, onChanged: (_) {})),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'Receipt photo');
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 400 * 3);
    });
  });
}
