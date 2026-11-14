import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_amount_field.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_history_item.dart';
import 'package:monivo/features/expenses/presentation/widgets/expense_date_picker.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_picker.dart';
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
      // spinner, and they are announced once, when they appear (UX-106).
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
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

  group('AppAmountField', () {
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
          AppAmountField(
            controller: controller,
            currency: 'INR',
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
          AppAmountField(
            controller: controller,
            currency: 'INR',
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

  Widget wrapped(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  // UX-081: the date field's error was excluded from what is read.
  testWidgets('the date field reads its error with it', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapped(
        ExpenseDatePicker(
          date: null,
          onChanged: (_) {},
          errorText: 'Choose a date.',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(ExpenseDatePicker)),
      containsSemantics(label: 'Date, Select date, Choose a date.'),
    );
    handle.dispose();
  });

  // UX-081: in a combined view the row's info button couldn't be reached.
  testWidgets('a combined row offers its info button as an action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    final day = DateTime(2026, 9, 10);
    await tester.pumpWidget(
      wrapped(
        ExpenseHistoryItem(
          expense: ExpenseEntity(
            id: 'e1',
            budgetId: 'b1',
            amount: 250,
            categoryId: 'food',
            date: day,
            time: day,
            createdAt: day,
            updatedAt: day,
          ),
          currency: 'INR',
          budgetName: 'Trip',
          onTap: () {},
          onInfoTap: () => opened++,
        ),
      ),
    );

    const action = CustomSemanticsAction(label: 'Expense and budget details');
    final node = tester.getSemantics(find.byType(ExpenseHistoryItem));
    expect(node, containsSemantics(customActions: [action]));
    expect(node.getSemanticsData().label, contains('250'));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(action),
    );
    expect(opened, 1);
    handle.dispose();
  });

  // UX-075: without a note, the row said its category twice.
  testWidgets('a row says its category once', (tester) async {
    final handle = tester.ensureSemantics();
    final day = DateTime(2026, 9, 10);
    final expense = ExpenseEntity(
      id: 'e1',
      budgetId: 'b1',
      amount: 250,
      categoryId: 'food',
      date: day,
      time: day,
      createdAt: day,
      updatedAt: day,
    );
    const food = ExpenseCategory(
      id: 'food',
      name: 'Food',
      icon: 'restaurant',
      colorHex: '#FF6B6B',
    );
    for (final note in [null, 'Pizza']) {
      await tester.pumpWidget(
        wrapped(
          ExpenseHistoryItem(
            expense: expense.copyWith(note: note),
            category: food,
            currency: 'INR',
            onTap: () {},
          ),
        ),
      );
      final label = tester
          .getSemantics(find.byType(ExpenseHistoryItem))
          .getSemanticsData()
          .label;
      expect(
        RegExp('Food').allMatches(label),
        hasLength(1),
        reason: 'note: $note, label: $label',
      );
      expect(label, startsWith(note == null ? 'Food, ' : 'Pizza, Food, '));
    }
    handle.dispose();
  });
}
