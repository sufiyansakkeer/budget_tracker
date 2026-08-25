import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/presentation/pages/budget_form_screen.dart';
import 'package:monivo/features/settings/domain/entities/app_settings.dart';
import 'package:monivo/features/settings/domain/entities/notification_settings.dart';
import 'package:monivo/features/settings/domain/entities/theme_mode_entity.dart';
import 'package:monivo/features/settings/domain/repository/settings_repository.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/usecases/get_budget_list_summary_usecase_test.mocks.dart';

class FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> loadSettings() async => const AppSettings();

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}

  @override
  Future<void> setCurrency(String code, String symbol) async {}

  @override
  Future<void> setNotificationSettings(NotificationSettings settings) async {}

  @override
  Future<void> setBiometricEnabled(bool enabled) async {}

  @override
  Future<void> setFirstLaunchCompleted() async {}
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    final repository = MockBudgetRepository();
    getIt.registerSingleton<BudgetRepository>(repository);
    getIt.registerSingleton<ManageBudgetUseCase>(
      ManageBudgetUseCase(repository: repository),
    );
    getIt.registerSingleton<CurrencyProvider>(
      CurrencyProvider(
        loadSettingsUseCase: LoadSettingsUseCase(
          repository: FakeSettingsRepository(),
        ),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpEditScreen(
    WidgetTester tester, {
    required String budgetId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: BudgetFormScreen(budgetId: budgetId)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  BudgetEntity budgetWithCurrency(String currency) {
    final startDate = DateTime(2026, 8, 1);
    return BudgetEntity(
      id: 'budget_$currency',
      name: 'Test Budget',
      monthlyAmount: 1500,
      remainingAmount: 1500,
      currency: currency,
      startDate: startDate,
      endDate: DateTime(2026, 8, 31),
      createdAt: startDate,
      updatedAt: startDate,
    );
  }

  testWidgets('editing an INR budget selects INR exactly once', (tester) async {
    final budget = budgetWithCurrency('INR');
    when(
      getIt<BudgetRepository>().getBudgetById(budget.id),
    ).thenAnswer((_) async => budget);

    await pumpEditScreen(tester, budgetId: budget.id);

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    final values = dropdown.items!.map((item) => item.value).toList();

    expect(dropdown.value, 'INR');
    expect(values.where((value) => value == 'INR'), hasLength(1));
    expect(values.toSet(), hasLength(values.length));
  });

  testWidgets('unsupported budget currency does not crash the form', (
    tester,
  ) async {
    final budget = budgetWithCurrency('XYZ');
    when(
      getIt<BudgetRepository>().getBudgetById(budget.id),
    ).thenAnswer((_) async => budget);

    await pumpEditScreen(tester, budgetId: budget.id);

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.value, isNull);
  });
}
