import '../entities/budget_entity.dart';
import '../repository/onboarding_repository.dart';

class CreateBudgetUseCase {
  final OnboardingRepository repository;

  CreateBudgetUseCase(this.repository);

  Future<void> call(BudgetEntity budget) async {
    await repository.createInitialBudget(budget);
    await repository.setFirstLaunchCompleted();
  }
}
