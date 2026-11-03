import '../../../../core/domain/entities/budget_entity.dart';
import '../repository/onboarding_repository.dart';

class CreateBudgetUseCase {
  final OnboardingRepository repository;

  CreateBudgetUseCase(this.repository);

  /// Saves the first budget. Saving the same budget again rewrites it, so a
  /// retry never makes a second one.
  Future<void> call(BudgetEntity budget) =>
      repository.createInitialBudget(budget);

  /// The last step: the app leaves onboarding for good, so call it only once
  /// the budget is saved and active.
  Future<void> finishOnboarding() => repository.setFirstLaunchCompleted();
}
