import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/welcome_step_widget.dart';
import '../widgets/budget_step_widget.dart';
import '../widgets/currency_step_widget.dart';
import '../widgets/confirmation_step_widget.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final countryCode = locale?.countryCode;

    return BlocProvider<OnboardingBloc>(
      create: (context) => getIt<OnboardingBloc>()
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.status == OnboardingStatus.success) {
          context.go(AppRouter.dashboardPath);
        } else if (state.status == OnboardingStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<OnboardingBloc>();
        final progress = (state.currentPageIndex + 1) / 4;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                // Animated Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${state.currentPageIndex + 1}/4',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      bloc.add(OnboardingPageChangedEvent(index));
                    },
                    children: [
                      // Screen 1: Welcome
                      WelcomeStepWidget(
                        onContinue: _nextPage,
                      ),
                      // Screen 2: Monthly Budget
                      BudgetStepWidget(
                        initialValue: state.monthlyBudgetInput,
                        currencySymbol: state.selectedCurrency.symbol,
                        errorMessage: state.budgetValidationError,
                        onChanged: (val) {
                          bloc.add(OnboardingBudgetInputChangedEvent(val));
                        },
                        onContinue: _nextPage,
                        onBack: _previousPage,
                      ),
                      // Screen 3: Currency Selection
                      CurrencyStepWidget(
                        selectedCurrency: state.selectedCurrency,
                        onSelected: (curr) {
                          bloc.add(OnboardingCurrencySelectedEvent(
                            code: curr.code,
                            symbol: curr.symbol,
                          ));
                        },
                        onContinue: _nextPage,
                        onBack: _previousPage,
                      ),
                      // Screen 4: Confirmation
                      ConfirmationStepWidget(
                        state: state,
                        onCreateBudget: () {
                          bloc.add(const OnboardingSubmittedEvent());
                        },
                        onBack: _previousPage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
