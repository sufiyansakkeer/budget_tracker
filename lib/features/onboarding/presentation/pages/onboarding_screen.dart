import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/budget_date_step_widget.dart';
import '../widgets/budget_name_step_widget.dart';
import '../widgets/budget_step_widget.dart';
import '../widgets/confirmation_step_widget.dart';
import '../widgets/currency_step_widget.dart';
import '../widgets/welcome_step_widget.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final countryCode = locale?.countryCode;

    return BlocProvider<OnboardingBloc>(
      create: (context) =>
          getIt<OnboardingBloc>()
            ..add(OnboardingInitEvent(localeCountryCode: countryCode)),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final PageController _pageController = PageController();
  static const int _totalSteps = 7;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: AppMotion.medium,
      curve: AppMotion.emphasizedCurve,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: AppMotion.medium,
      curve: AppMotion.emphasizedCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.status == OnboardingStatus.success) {
          context.go(AppRouter.homePath);
        } else if (state.status == OnboardingStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final bloc = context.read<OnboardingBloc>();
        final step = state.currentPageIndex + 1;

        // System back moves one step back instead of leaving onboarding.
        return PopScope(
          canPop: state.currentPageIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _previousPage();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Step $step of $_totalSteps',
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: step / _totalSteps),
                              duration: AppMotion.respectReducedMotion(
                                context,
                                AppMotion.medium,
                              ),
                              curve: AppMotion.standardCurve,
                              builder: (context, value, _) => ClipRRect(
                                borderRadius: AppSpacing.borderRadiusFull,
                                child: LinearProgressIndicator(
                                  value: value,
                                  minHeight: AppSizes.progressSm,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.smd),
                        ExcludeSemantics(
                          child: Text(
                            '$step / $_totalSteps',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        bloc.add(OnboardingPageChangedEvent(index));
                      },
                      children: [
                        WelcomeStepWidget(onContinue: _nextPage),
                        BudgetNameStepWidget(
                          initialValue: state.budgetNameInput,
                          errorMessage: state.nameValidationError,
                          onChanged: (val) =>
                              bloc.add(OnboardingBudgetNameChangedEvent(val)),
                          onContinue: _nextPage,
                          onBack: _previousPage,
                        ),
                        BudgetStepWidget(
                          initialValue: state.monthlyBudgetInput,
                          currencySymbol: state.selectedCurrency.symbol,
                          errorMessage: state.budgetValidationError,
                          onChanged: (val) =>
                              bloc.add(OnboardingBudgetInputChangedEvent(val)),
                          onContinue: _nextPage,
                          onBack: _previousPage,
                        ),
                        CurrencyStepWidget(
                          selectedCurrency: state.selectedCurrency,
                          onSelected: (curr) => bloc.add(
                            OnboardingCurrencySelectedEvent(
                              code: curr.code,
                              symbol: curr.symbol,
                            ),
                          ),
                          onContinue: _nextPage,
                          onBack: _previousPage,
                        ),
                        BudgetDateStepWidget(
                          title: 'When does your budget start?',
                          subtitle: 'Any date works. It defaults to today.',
                          date: state.startDate,
                          onDateChanged: (d) =>
                              bloc.add(OnboardingStartDateChangedEvent(d)),
                          onContinue: _nextPage,
                          onBack: _previousPage,
                        ),
                        BudgetDateStepWidget(
                          title: 'When does your budget end?',
                          subtitle:
                              'A budget can span days, weeks, months or a '
                              "year. Today's Safe Spending is worked out from "
                              'the days left until this date.',
                          date: state.endDate,
                          errorMessage: state.dateValidationError,
                          onDateChanged: (d) =>
                              bloc.add(OnboardingEndDateChangedEvent(d)),
                          onContinue: _nextPage,
                          onBack: _previousPage,
                        ),
                        ConfirmationStepWidget(
                          state: state,
                          onCreateBudget: () =>
                              bloc.add(const OnboardingSubmittedEvent()),
                          onBack: _previousPage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
