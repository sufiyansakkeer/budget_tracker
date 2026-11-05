import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_provider.dart';
import 'package:monivo/core/dates/calendar_dates.dart';
import 'package:monivo/core/di/injection.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/onboarding/domain/usecases/create_budget_usecase.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:monivo/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:monivo/features/settings/domain/repository/settings_repository.dart';
import 'package:monivo/features/settings/domain/usecases/load_settings_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/update_currency_usecase.dart';

import 'onboarding_continue_test.dart'
    show FakeBudgetRepository, FakeOnboardingRepository;

/// Creating the budget waits until the test lets it fail.
class _SlowOnboardingRepository extends FakeOnboardingRepository {
  final gate = Completer<void>();

  @override
  Future<void> createInitialBudget(BudgetEntity budget) => gate.future;
}

class _UnusedSettingsRepository extends Fake implements SettingsRepository {}

/// UX-094 (onboarding part) and UX-104, through the real screen.
void main() {
  late _SlowOnboardingRepository onboardingRepository;
  late OnboardingBloc bloc;

  // Made inside each test, so the bloc's async work runs in the test's
  // fake-async zone and under pump.
  void makeBloc() {
    onboardingRepository = _SlowOnboardingRepository();
    final settings = _UnusedSettingsRepository();
    bloc = OnboardingBloc(
      createBudgetUseCase: CreateBudgetUseCase(onboardingRepository),
      budgetRepository: FakeBudgetRepository(),
      updateCurrencyUseCase: UpdateCurrencyUseCase(repository: settings),
      currencyProvider: CurrencyProvider(
        loadSettingsUseCase: LoadSettingsUseCase(repository: settings),
      ),
    );
    if (getIt.isRegistered<OnboardingBloc>()) {
      getIt.unregister<OnboardingBloc>();
    }
    getIt.registerFactory<OnboardingBloc>(() => bloc);
  }

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool reducedMotion = false,
  }) async {
    makeBloc();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.tap(finder.hitTestable());
    await tester.pumpAndSettle();
  }

  /// Welcome → name → currency → amount → start → end.
  Future<void> goToEndStep(WidgetTester tester) async {
    await tapVisible(tester, find.text('Get started'));
    await tester.enterText(
      find.byKey(const Key('budgetNameTextField')),
      'Personal',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('budgetNameContinueButton')));
    await tapVisible(tester, find.text('Continue'));
    await tester.enterText(
      find.byKey(const Key('monthlyBudgetTextField')),
      '3000',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('budgetStepContinueButton')));
    await tapVisible(tester, find.byKey(const Key('dateStepContinueButton')));
    expect(bloc.state.currentPageIndex, 5);
  }

  testWidgets('UX-104: steps change under reduced motion without asserting', (
    tester,
  ) async {
    await pumpScreen(tester, reducedMotion: true);

    await tapVisible(tester, find.text('Get started'));
    expect(tester.takeException(), isNull);
    expect(bloc.state.currentPageIndex, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(bloc.state.currentPageIndex, 0);
  });

  // UX-111: the field autofocused as its page slid in, so the keyboard
  // opened and resized the screen mid-transition.
  bool focused(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode
      .hasFocus;

  testWidgets('UX-111: a step\'s field takes focus once its page settles', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Get started').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-slide: the name step is built but not focused.
    expect(find.byKey(const Key('budgetNameTextField')), findsOneWidget);
    expect(focused(tester, 'budgetNameTextField'), isFalse);

    await tester.pumpAndSettle();
    expect(focused(tester, 'budgetNameTextField'), isTrue);

    // The amount step (after currency) does the same.
    await tester.enterText(
      find.byKey(const Key('budgetNameTextField')),
      'Personal',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('budgetNameContinueButton')));
    await tester.tap(find.text('Continue').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(focused(tester, 'monthlyBudgetTextField'), isFalse);
    await tester.pumpAndSettle();
    expect(focused(tester, 'monthlyBudgetTextField'), isTrue);
  });

  testWidgets('UX-111: under reduced motion the field focuses at once', (
    tester,
  ) async {
    await pumpScreen(tester, reducedMotion: true);
    await tester.tap(find.text('Get started').hitTestable());
    await tester.pump();
    await tester.pump();
    expect(focused(tester, 'budgetNameTextField'), isTrue);
  });

  testWidgets('UX-094: the end picker starts the day after the start', (
    tester,
  ) async {
    await pumpScreen(tester);
    await goToEndStep(tester);

    // The card names the date it changes.
    expect(find.bySemanticsLabel(RegExp(r'^End date ')), findsOneWidget);

    await tapVisible(tester, find.byIcon(Icons.edit_calendar_rounded));
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, bloc.state.startDate.addDays(1));
  });

  testWidgets('UX-098: the start card names the start date', (tester) async {
    await pumpScreen(tester);
    await tapVisible(tester, find.text('Get started'));
    await tester.enterText(
      find.byKey(const Key('budgetNameTextField')),
      'Personal',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('budgetNameContinueButton')));
    await tapVisible(tester, find.text('Continue'));
    await tester.enterText(
      find.byKey(const Key('monthlyBudgetTextField')),
      '3000',
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('budgetStepContinueButton')));

    expect(find.bySemanticsLabel(RegExp(r'^Start date ')), findsOneWidget);
  });

  testWidgets('UX-094: system Back does nothing while the budget is created', (
    tester,
  ) async {
    await pumpScreen(tester);
    await goToEndStep(tester);
    await tapVisible(tester, find.byKey(const Key('dateStepContinueButton')));
    expect(bloc.state.currentPageIndex, 6);

    await tester.tap(find.byKey(const Key('createBudgetButton')));
    await tester.pump();
    expect(bloc.state.status, OnboardingStatus.loading);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(bloc.state.currentPageIndex, 6);

    // Once creating fails, Back works again.
    onboardingRepository.gate.completeError('disk full');
    await tester.pumpAndSettle();
    expect(bloc.state.status, OnboardingStatus.failure);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(bloc.state.currentPageIndex, 5);
  });
}
